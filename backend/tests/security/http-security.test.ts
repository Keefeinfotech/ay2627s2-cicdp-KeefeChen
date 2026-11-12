import request from "supertest";
import { describe, expect, it } from "vitest";
import app from "../../src/app";

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

describe("HTTP security headers", () => {
  it("sets defensive headers and hides the server banner", async () => {
    const res = await request(app).get("/api/health");

    expect(res.status).toBe(200);
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["x-frame-options"]).toBe("SAMEORIGIN");
    expect(res.headers["x-powered-by"]).toBeUndefined();
    expect(res.headers["referrer-policy"]).toBe("no-referrer");
  });

  it("issues a request id for correlation", async () => {
    const res = await request(app).get("/api/health");
    expect(res.headers["x-request-id"]).toMatch(UUID_PATTERN);
  });

  it("prevents caching of auth responses", async () => {
    const res = await request(app).get("/api/auth/me");
    expect(res.headers["cache-control"]).toBe("no-store");
  });

  it("accepts a safe inbound request id", async () => {
    const res = await request(app)
      .get("/api/health")
      .set("X-Request-Id", "client-request-123");

    expect(res.headers["x-request-id"]).toBe("client-request-123");
  });

  it("replaces an unsafe inbound request id", async () => {
    const res = await request(app)
      .get("/api/health")
      .set("X-Request-Id", "bad id with spaces");

    expect(res.headers["x-request-id"]).toMatch(UUID_PATTERN);
    expect(res.headers["x-request-id"]).not.toBe("bad id with spaces");
  });
});

describe("CORS policy", () => {
  it("allows an origin on the allow-list", async () => {
    const res = await request(app)
      .get("/api/health")
      .set("Origin", "http://localhost:5173");

    expect(res.status).toBe(200);
    expect(res.headers["access-control-allow-origin"]).toBe(
      "http://localhost:5173"
    );
  });

  it("allows a loopback origin on any port in development", async () => {
    const res = await request(app)
      .options("/api/auth/forgot-password")
      .set("Origin", "http://localhost:63488")
      .set("Access-Control-Request-Method", "POST")
      .set("Access-Control-Request-Headers", "content-type");

    expect(res.status).toBe(204);
    expect(res.headers["access-control-allow-origin"]).toBe(
      "http://localhost:63488"
    );
  });

  it("rejects an unknown browser origin", async () => {
    const res = await request(app)
      .get("/api/health")
      .set("Origin", "https://evil.example.com");

    expect(res.status).toBe(403);
    expect(res.body.code).toBe("CORS_FORBIDDEN");
  });
});

describe("request body limits", () => {
  it("rejects oversized JSON payloads", async () => {
    const res = await request(app).post("/api/auth/login").send({
      email: "ada@example.com",
      password: "x".repeat(20_000),
    });

    expect(res.status).toBe(413);
    expect(res.body.code).toBe("PAYLOAD_TOO_LARGE");
  });
});
