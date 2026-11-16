/**
 * File Name: rateLimiterRedis.test.ts
 * Description: Exercises the Redis-backed rate limiter against a minimal
 * RESP (Redis Serialization Protocol) server implemented in-process. It
 * verifies that two independent limiter instances (e.g. two replicas)
 * enforce a shared counter through the same Redis, which is the whole
 * point of the Redis store. No external Redis is required.
 */

import net from "node:net";
import crypto from "node:crypto";
import express from "express";
import request from "supertest";
import { afterEach, describe, expect, it } from "vitest";
import { createRateLimiter } from "../../src/middleware/rateLimiter";
import { connectRedis, closeRedisClient } from "../../src/config/redis";

const originalRedisUrl = process.env.REDIS_URL;

// ---------------------------------------------------------------------------
// Minimal in-process RESP server supporting just enough of the protocol for
// rate-limit-redis: SCRIPT LOAD, EVALSHA (increment script), DECR, DEL, QUIT.
// ---------------------------------------------------------------------------

interface FakeCounter {
  hits: number;
  expiresAt: number;
}

const parseCommand = (
  buffer: Buffer,
): { tokens: string[]; consumed: number } | null => {
  if (buffer.length === 0 || buffer[0] !== 0x2a /* '*' */) return null;
  const lines: string[] = [];
  let offset = 0;
  const readLine = (): string | null => {
    const idx = buffer.indexOf("\r\n", offset);
    if (idx === -1) return null;
    const line = buffer.toString("utf8", offset, idx);
    offset = idx + 2;
    return line;
  };

  const first = readLine();
  if (first === null) return null;
  const count = Number(first.slice(1));
  for (let i = 0; i < count; i += 1) {
    if (buffer[offset] !== 0x24 /* '$' */) return null;
    const lenLine = readLine();
    if (lenLine === null) return null;
    const len = Number(lenLine.slice(1));
    if (offset + len + 2 > buffer.length) return null;
    lines.push(buffer.toString("utf8", offset, offset + len));
    offset += len + 2; // skip payload + CRLF
  }
  return { tokens: lines, consumed: offset };
};

const encodeReply = (reply: unknown): Buffer => {
  if (typeof reply === "number") {
    return Buffer.from(`:${reply}\r\n`, "utf8");
  }
  if (typeof reply === "string") {
    const payload = Buffer.from(reply, "utf8");
    return Buffer.concat([
      Buffer.from(`$${payload.length}\r\n`, "utf8"),
      payload,
      Buffer.from("\r\n", "utf8"),
    ]);
  }
  if (Array.isArray(reply)) {
    const parts = [Buffer.from(`*${reply.length}\r\n`, "utf8")];
    for (const item of reply) parts.push(encodeReply(item));
    return Buffer.concat(parts);
  }
  return Buffer.from("+OK\r\n", "utf8");
};

const startFakeRedis = (): Promise<{
  url: string;
  close: () => Promise<void>;
}> => {
  const counters = new Map<string, FakeCounter>();
  const server = net.createServer((socket) => {
    let buffer = Buffer.alloc(0);
    socket.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      for (;;) {
        const parsed = parseCommand(buffer);
        if (!parsed) break;

        const { tokens, consumed } = parsed;
        buffer = buffer.subarray(consumed);
        const command = tokens[0]?.toUpperCase();

        if (command === "CLIENT") {
          socket.write(encodeReply("OK"));
          continue;
        }

        if (command === "INFO") {
          socket.write(
            encodeReply(
              "# Server\r\nredis_version:7.2.0\r\nrole:master\r\nconnected_clients:1\r\n",
            ),
          );
          continue;
        }

        if (command === "PING") {
          socket.write(Buffer.from("+PONG\r\n", "utf8"));
          continue;
        }

        if (command === "SCRIPT" && tokens[1]?.toUpperCase() === "LOAD") {
          const sha = crypto
            .createHash("sha1")
            .update(tokens[2] ?? "")
            .digest("hex");
          socket.write(encodeReply(sha));
          continue;
        }

        if (command === "EVALSHA") {
          const key = tokens[3]!;
          const windowMs = Number(tokens[4] ?? "60000");
          const now = Date.now();
          let entry = counters.get(key);
          if (!entry || entry.expiresAt <= now) {
            entry = { hits: 1, expiresAt: now + windowMs };
            counters.set(key, entry);
            socket.write(encodeReply([1, windowMs]));
          } else {
            entry.hits += 1;
            socket.write(encodeReply([entry.hits, entry.expiresAt - now]));
          }
          continue;
        }

        if (command === "DEL") {
          counters.delete(tokens[1]!);
          socket.write(encodeReply(1));
          continue;
        }

        if (command === "DECR") {
          const entry = counters.get(tokens[1]!);
          if (entry) entry.hits = Math.max(0, entry.hits - 1);
          socket.write(encodeReply(entry?.hits ?? 0));
          continue;
        }

        if (command === "QUIT") {
          socket.write(encodeReply("OK"));
          socket.end();
          continue;
        }

        socket.write(
          Buffer.from(`-ERR unknown command ${command ?? ""}\r\n`, "utf8"),
        );
      }
    });
  });

  return new Promise((resolve, reject) => {
    server.on("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      if (address === null || typeof address === "string") {
        reject(new Error("Could not start fake Redis"));
        return;
      }
      resolve({
        url: `redis://127.0.0.1:${address.port}`,
        close: () => new Promise<void>((done) => server.close(() => done())),
      });
    });
  });
};

afterEach(async () => {
  if (originalRedisUrl === undefined) {
    delete process.env.REDIS_URL;
  } else {
    process.env.REDIS_URL = originalRedisUrl;
  }
  await closeRedisClient();
});

describe("rate limiter with Redis store", () => {
  it("enforces a shared counter across limiter instances", async () => {
    const fake = await startFakeRedis();
    process.env.REDIS_URL = fake.url;
    await connectRedis();

    const makeApp = () => {
      const app = express();
      app.use(
        createRateLimiter({
          name: "replica-shared",
          windowMs: 60_000,
          limit: 2,
          message: { error: "Too many requests, please try again later." },
        }),
      );
      app.get("/", (_req, res) => {
        res.status(200).json({ ok: true });
      });
      return app;
    };

    // Two apps stand in for two backend replicas behind a load balancer.
    const replicaA = makeApp();
    const replicaB = makeApp();

    const responses = [];
    responses.push(await request(replicaA).get("/"));
    responses.push(await request(replicaB).get("/"));
    responses.push(await request(replicaA).get("/"));

    expect(responses.map((res) => res.status)).toEqual([200, 200, 429]);

    // Close the client first: the fake server only finishes closing once
    // its open sockets are gone.
    await closeRedisClient();
    await fake.close();
  });
});
