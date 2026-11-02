import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/modules/auth/auth.model.js", () => ({
  User: {
    findById: vi.fn(),
    updateOne: vi.fn(),
  },
}));

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { signAccessToken } from "../../src/shared/utils/tokens";

const userModel = User as any;

const queryResult = (value: unknown) => ({
  exec: vi.fn().mockResolvedValue(value),
});

const withSession = (
  sessionId: string,
  overrides: Record<string, unknown> = {}
) =>
  userModel.findById.mockReturnValue(
    queryResult({
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      activeSessionId: sessionId,
      activeSessionExpiresAt: new Date(Date.now() + 60 * 60 * 1000),
      ...overrides,
    })
  );

beforeEach(() => {
  vi.clearAllMocks();
});

afterEach(() => {
  delete process.env.CAPTCHA_ENABLED;
  delete process.env.TURNSTILE_SECRET_KEY;
});

describe("session enforcement", () => {
  it("rejects a request without a token", async () => {
    const res = await request(app).get("/api/auth/me");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("returns the current user for the active session", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withSession(sessionId);

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe("ada@example.com");
    expect(res.body.user).not.toHaveProperty("role");
  });

  it("rejects a token replaced by a newer login", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    withSession("session-from-another-device");

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("SESSION_REPLACED");
  });

  it("rejects an expired stored session", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withSession(sessionId, {
      activeSessionExpiresAt: new Date(Date.now() - 60_000),
    });

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("SESSION_REPLACED");
  });

  it("rejects a token for a deleted account", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    userModel.findById.mockReturnValue(queryResult(null));

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("clears the session on logout", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withSession(sessionId);
    userModel.updateOne.mockReturnValue(
      queryResult({ acknowledged: true })
    );

    const res = await request(app)
      .post("/api/auth/logout")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(204);
    expect(userModel.updateOne).toHaveBeenCalledWith(
      { _id: "user-1" },
      { $set: { activeSessionId: null, activeSessionExpiresAt: null } }
    );
  });
});

describe("CAPTCHA enforcement", () => {
  it("requires a token when CAPTCHA is enabled", async () => {
    process.env.CAPTCHA_ENABLED = "true";
    process.env.TURNSTILE_SECRET_KEY = "test-secret";

    const res = await request(app)
      .post("/api/auth/login")
      .send({ email: "ada@example.com", password: "password123" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("CAPTCHA_REQUIRED");
  });

  it("fails closed when CAPTCHA is enabled without a secret", async () => {
    process.env.CAPTCHA_ENABLED = "true";

    const res = await request(app)
      .post("/api/auth/login")
      .send({
        email: "ada@example.com",
        password: "password123",
        captchaToken: "token",
      });

    expect(res.status).toBe(503);
    expect(res.body.code).toBe("CAPTCHA_NOT_CONFIGURED");
  });

  it("accepts a token from the X-Captcha-Token header", async () => {
    process.env.CAPTCHA_ENABLED = "true";
    process.env.TURNSTILE_SECRET_KEY = "test-secret";
    const fetchMock = vi
      .spyOn(globalThis, "fetch")
      .mockResolvedValue(
        new Response(JSON.stringify({ success: true }), { status: 200 })
      );

    const res = await request(app)
      .post("/api/auth/login")
      .set("X-Captcha-Token", "header-token")
      .send({ email: "not-an-email", password: "x" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
    expect(fetchMock).toHaveBeenCalledTimes(1);
    fetchMock.mockRestore();
  });

  it("is skipped when CAPTCHA is disabled (local development)", async () => {
    process.env.CAPTCHA_ENABLED = "false";

    const res = await request(app)
      .post("/api/auth/login")
      .send({ email: "not-an-email", password: "x" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });
});
