import express from "express";
import request from "supertest";
import { afterEach, describe, expect, it, vi } from "vitest";
import { createRateLimiter } from "../../src/middleware/rateLimiter";
import { closeRedisClient } from "../../src/config/redis";
import { requestId } from "../../src/middleware/requestId";

const originalRedisUrl = process.env.REDIS_URL;

afterEach(async () => {
  if (originalRedisUrl === undefined) {
    delete process.env.REDIS_URL;
  } else {
    process.env.REDIS_URL = originalRedisUrl;
  }
  await closeRedisClient();
  vi.restoreAllMocks();
});

describe("rate limiter with an unreachable Redis", () => {
  it("fails open instead of returning 5xx", async () => {
    // Nothing listens on port 1; connectTimeout and enableOfflineQueue are
    // configured so commands reject immediately instead of hanging.
    process.env.REDIS_URL = "redis://127.0.0.1:1";

    const app = express();
    app.use(requestId);
    app.use(
      createRateLimiter({
        name: "test-redis-unavailable",
        windowMs: 60_000,
        limit: 1,
        message: { error: "Too many requests, please try again later." },
      }),
    );
    app.get("/", (_req, res) => {
      res.status(200).json({ ok: true });
    });

    const res = await request(app).get("/");

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ ok: true });
  });
});

describe("rate limiter without Redis", () => {
  it("uses the in-process store and enforces the limit", async () => {
    delete process.env.REDIS_URL;

    const app = express();
    app.use(requestId);
    app.use(
      createRateLimiter({
        name: "test-memory-store",
        windowMs: 60_000,
        limit: 1,
        message: { error: "Too many requests, please try again later." },
      }),
    );
    app.get("/", (_req, res) => {
      res.status(200).json({ ok: true });
    });

    const first = await request(app).get("/");
    const second = await request(app).get("/");

    expect(first.status).toBe(200);
    expect(second.status).toBe(429);
  });
});
