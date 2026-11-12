import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

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
import { generateRefreshToken } from "../../src/shared/utils/refreshTokens";
import { verifyAccessToken } from "../../src/shared/utils/tokens";

const userModel = User as any;
const sessionModel = AuthSession as any;

// Query result helper supporting the .select()/.exec() chains.
const queryResult = (value: unknown) => ({
  select: vi.fn().mockReturnThis(),
  sort: vi.fn().mockReturnThis(),
  exec: vi.fn().mockResolvedValue(value),
});

const activeUser = () => ({
  _id: "user-1",
  name: "Ada",
  email: "ada@example.com",
  role: "user",
  save: vi.fn().mockResolvedValue(undefined),
});

// Serves a live session row whose current refresh hash matches `hash`.
const withLiveSession = (
  sessionId: string,
  overrides: Record<string, unknown> = {},
  hash?: string
) => {
  sessionModel.findById.mockReturnValue(
    queryResult({
      _id: sessionId,
      userId: "user-1",
      refreshTokenHash: hash ?? null,
      previousRefreshTokenHash: null,
      refreshedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000),
      ...overrides,
    })
  );
  userModel.findById.mockReturnValue(queryResult(activeUser()));
};

beforeEach(() => {
  vi.clearAllMocks();
  sessionCache.clear();
  // Default query chains: rotation and revocation call updateOne().exec().
  sessionModel.updateOne.mockReturnValue(queryResult({ acknowledged: true }));
  sessionModel.updateMany.mockReturnValue(queryResult({ acknowledged: true }));
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  userModel.save = vi.fn();
});

describe("POST /api/auth/refresh", () => {
  it("rotates the refresh token and issues a new access token", async () => {
    const issued = generateRefreshToken("session-1");
    withLiveSession("session-1", {}, issued.hash);

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: issued.token });

    expect(res.status).toBe(200);
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.refreshToken).not.toBe(issued.token);

    // The new access token keeps pointing at the same session.
    const payload = verifyAccessToken(res.body.token);
    expect(payload?.sub).toBe("user-1");
    expect(payload?.jti).toBe("session-1");
    expect(res.body.user.email).toBe("ada@example.com");

    // Rotation stores the new hash and keeps the old one as `previous`.
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: "session-1" },
      {
        $set: expect.objectContaining({
          refreshTokenHash: expect.any(String),
          previousRefreshTokenHash: issued.hash,
          refreshedAt: expect.any(Date),
          lastUsedAt: expect.any(Date),
        }),
      }
    );
    const $set = (sessionModel.updateOne.mock.calls[0][1] as any).$set;
    expect($set.refreshTokenHash).not.toBe(issued.hash);
  });

  it("accepts a chained refresh with the rotated token", async () => {
    const first = generateRefreshToken("session-1");
    withLiveSession("session-1", {}, first.hash);

    const res1 = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: first.token });
    expect(res1.status).toBe(200);

    // Simulate the database picking up the rotation.
    const nextHash = (sessionModel.updateOne.mock.calls[0][1] as any).$set
      .refreshTokenHash as string;
    withLiveSession(
      "session-1",
      {
        previousRefreshTokenHash: first.hash,
        refreshedAt: new Date(),
      },
      nextHash
    );

    const res2 = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: res1.body.refreshToken });

    expect(res2.status).toBe(200);
    expect(res2.body.refreshToken).not.toBe(res1.body.refreshToken);
    expect(verifyAccessToken(res2.body.token)?.jti).toBe("session-1");
  });

  it("tolerates a racing refresh with the previous token inside the grace window", async () => {
    const previous = generateRefreshToken("session-1");
    const current = generateRefreshToken("session-1");
    withLiveSession(
      "session-1",
      {
        previousRefreshTokenHash: previous.hash,
        refreshedAt: new Date(Date.now() - 2_000),
      },
      current.hash
    );

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: previous.token });

    expect(res.status).toBe(200);
    expect(res.body.refreshToken).toBeTruthy();
  });

  it("revokes the session when a rotated token is replayed after the grace window", async () => {
    const previous = generateRefreshToken("session-1");
    const current = generateRefreshToken("session-1");
    withLiveSession(
      "session-1",
      {
        previousRefreshTokenHash: previous.hash,
        // Past REFRESH_REUSE_GRACE_MS (10s): assume the token was stolen.
        refreshedAt: new Date(Date.now() - 30_000),
      },
      current.hash
    );

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: previous.token });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
    // The whole session is revoked, not just the presented token.
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: "session-1", userId: "user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } }
    );
  });

  it("rejects a tampered secret without revoking the session", async () => {
    const issued = generateRefreshToken("session-1");
    const other = generateRefreshToken("session-1");
    withLiveSession("session-1", {}, issued.hash);

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: other.token });

    expect(res.status).toBe(401);
    expect(sessionModel.updateOne).not.toHaveBeenCalled();
  });

  it("rejects a malformed refresh token without a database lookup", async () => {
    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: "not-a-refresh-token" });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
    expect(sessionModel.findById).not.toHaveBeenCalled();
  });

  it("rejects a refresh token for an unknown session", async () => {
    sessionModel.findById.mockReturnValue(queryResult(null));

    const issued = generateRefreshToken("session-ghost");
    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: issued.token });

    expect(res.status).toBe(401);
    expect(sessionModel.updateOne).not.toHaveBeenCalled();
  });

  it("rejects a refresh token for a revoked session", async () => {
    const issued = generateRefreshToken("session-1");
    withLiveSession(
      "session-1",
      { revokedAt: new Date(Date.now() - 1000) },
      issued.hash
    );

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: issued.token });

    expect(res.status).toBe(401);
    expect(sessionModel.updateOne).not.toHaveBeenCalled();
  });

  it("rejects a refresh token for an expired session", async () => {
    const issued = generateRefreshToken("session-1");
    withLiveSession(
      "session-1",
      { expiresAt: new Date(Date.now() - 1000) },
      issued.hash
    );

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: issued.token });

    expect(res.status).toBe(401);
    expect(sessionModel.updateOne).not.toHaveBeenCalled();
  });

  it("revokes the session when the account no longer exists", async () => {
    const issued = generateRefreshToken("session-1");
    withLiveSession("session-1", {}, issued.hash);
    userModel.findById.mockReturnValue(queryResult(null));

    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: issued.token });

    expect(res.status).toBe(401);
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: "session-1", userId: "user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } }
    );
  });

  it("requires a refresh token", async () => {
    const res = await request(app).post("/api/auth/refresh").send({});

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });

  it("rejects an empty refresh token", async () => {
    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: "   " });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });

  it("rejects unknown fields", async () => {
    const res = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: "x".repeat(40), token: "admin" });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
  });
});
