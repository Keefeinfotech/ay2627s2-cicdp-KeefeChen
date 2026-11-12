import request from "supertest";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/modules/auth/auth.model.js", () => ({
  User: {
    findOne: vi.fn(),
    create: vi.fn(),
    findById: vi.fn(),
  },
}));

vi.mock("../../src/modules/auth/session.model.js", () => ({
  AuthSession: {
    create: vi.fn(),
    findById: vi.fn(),
    find: vi.fn(),
    updateOne: vi.fn(),
    updateMany: vi.fn(),
  },
}));

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";

const userModel = User as any;
const sessionModel = AuthSession as any;

// Query helper supporting the .select()/.sort()/.exec() chains used by the
// repositories.
const queryResult = (value: unknown) => ({
  select: vi.fn().mockReturnThis(),
  sort: vi.fn().mockReturnThis(),
  exec: vi.fn().mockResolvedValue(value),
});

const future = new Date(Date.now() + 60 * 60 * 1000);
const past = new Date(Date.now() - 60 * 1000);

const activeSession = (
  sessionId: string,
  overrides: Record<string, unknown> = {},
) => ({
  _id: sessionId,
  userId: "user-1",
  refreshTokenHash: "stored-hash",
  previousRefreshTokenHash: null,
  refreshedAt: null,
  userAgent: "vitest",
  lastUsedAt: new Date(),
  expiresAt: future,
  revokedAt: null,
  createdAt: new Date(),
  ...overrides,
});

const withUser = (overrides: Record<string, unknown> = {}) =>
  userModel.findById.mockReturnValue(
    queryResult({
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      ...overrides,
    }),
  );

const withSession = (
  sessionId: string,
  overrides: Record<string, unknown> = {},
) =>
  sessionModel.findById.mockReturnValue(
    queryResult(activeSession(sessionId, overrides)),
  );

beforeEach(() => {
  vi.clearAllMocks();
  // The validated-session cache is a module singleton; stale entries would
  // leak between tests and mask revocation behaviour.
  sessionCache.clear();
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

  it("returns the current user for an active session", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId);

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe("ada@example.com");
    expect(res.body.user).not.toHaveProperty("role");
  });

  it("rejects a revoked session as replaced", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId, { revokedAt: new Date() });

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("SESSION_REPLACED");
  });

  it("rejects an expired session", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId, { expiresAt: past });

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("rejects a session that belongs to another user", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId, { userId: "user-2" });

    const res = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
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

  it("caches validated sessions instead of re-reading MongoDB", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId);

    const first = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);
    const second = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    expect(first.status).toBe(200);
    expect(second.status).toBe(200);
    // The session row is read once; the second request is served from cache.
    // getCurrentUser still reads the user document per request (3 total:
    // 2 in the first authenticate + 1 in the second, cache-hit request).
    expect(sessionModel.findById).toHaveBeenCalledTimes(1);
    expect(userModel.findById).toHaveBeenCalledTimes(3);
  });

  it("logout revokes only the calling session and drops its cache entry", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId);
    sessionModel.updateOne.mockReturnValue({
      exec: vi.fn().mockResolvedValue({ acknowledged: true }),
    });

    // Prime the cache first so logout must invalidate it.
    await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);

    const res = await request(app)
      .post("/api/auth/logout")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(204);
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: sessionId, userId: "user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } },
    );
    // The revoked session must not be served from the cache.
    const after = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${token}`);
    expect(after.status).toBe(200);
    expect(sessionModel.findById).toHaveBeenCalledTimes(2);
  });
});

describe("GET /api/auth/sessions", () => {
  it("requires authentication", async () => {
    const res = await request(app).get("/api/auth/sessions");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("lists active sessions and flags the calling one as current", async () => {
    const { token, sessionId } = signAccessToken("user-1", "ada@example.com");
    withUser();
    withSession(sessionId);
    sessionModel.find.mockReturnValue(
      queryResult([
        activeSession(sessionId),
        activeSession("session-2", { userAgent: null }),
      ]),
    );

    const res = await request(app)
      .get("/api/auth/sessions")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.sessions).toHaveLength(2);
    expect(res.body.sessions[0]).toMatchObject({
      id: sessionId,
      current: true,
      userAgent: "vitest",
    });
    expect(res.body.sessions[1]).toMatchObject({
      id: "session-2",
      current: false,
      userAgent: null,
    });
    expect(sessionModel.find).toHaveBeenCalledWith({
      userId: "user-1",
      revokedAt: null,
      expiresAt: { $gt: expect.any(Date) },
    });
  });
});

describe("DELETE /api/auth/sessions/:id", () => {
  // The token's own session stays active; the given target id resolves to
  // nothing, as if it never existed or was already purged.
  const missingSession = (targetId: string) =>
    sessionModel.findById.mockImplementation((id: string) =>
      queryResult(id === targetId ? null : activeSession("session-current")),
    );

  it("requires authentication", async () => {
    const res = await request(app).delete("/api/auth/sessions/session-2");
    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("revokes one of the caller's sessions", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    withUser();
    sessionModel.findById.mockImplementation((id: string) =>
      queryResult(
        id === "session-2"
          ? activeSession("session-2")
          : activeSession("session-current"),
      ),
    );
    sessionModel.updateOne.mockReturnValue({
      exec: vi.fn().mockResolvedValue({ acknowledged: true }),
    });

    const res = await request(app)
      .delete("/api/auth/sessions/session-2")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(204);
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: "session-2", userId: "user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } },
    );
  });

  it("returns 404 for an unknown session", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    withUser();
    missingSession("no-such-session");

    const res = await request(app)
      .delete("/api/auth/sessions/no-such-session")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(404);
    expect(res.body.code).toBe("NOT_FOUND");
  });

  it("returns 404 for another user's session", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    withUser();
    sessionModel.findById.mockImplementation((id: string) =>
      queryResult(
        id === "session-2"
          ? activeSession("session-2", { userId: "user-2" })
          : activeSession("session-current"),
      ),
    );

    const res = await request(app)
      .delete("/api/auth/sessions/session-2")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(404);
    expect(res.body.code).toBe("NOT_FOUND");
  });

  it("is idempotent for an already-revoked session", async () => {
    const { token } = signAccessToken("user-1", "ada@example.com");
    withUser();
    sessionModel.findById.mockImplementation((id: string) =>
      queryResult(
        id === "session-2"
          ? activeSession("session-2", { revokedAt: new Date() })
          : activeSession("session-current"),
      ),
    );

    const res = await request(app)
      .delete("/api/auth/sessions/session-2")
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(204);
    expect(sessionModel.updateOne).not.toHaveBeenCalled();
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

    const res = await request(app).post("/api/auth/login").send({
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
        new Response(JSON.stringify({ success: true }), { status: 200 }),
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
