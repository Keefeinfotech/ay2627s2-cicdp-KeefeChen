/*
 * File Name: known-issues.test.ts
 * Description: Regression tests for defects that were fixed previously. Each
 *   test names the incident it guards so a future refactor that reintroduces
 *   the bug fails with a meaningful message.
 *
 *   Incident references (git history, feature/enterprise-cicd-pipeline):
 *   - f655296 fix(web): restore strict CSP from main (web regression, covered
 *     by the nginx config — see e2e + docs/testing/MANUAL_TEST_PLAN.md)
 *   - d81bd7a / f0d4369 fix(calendar): validate identifiers before they reach
 *     Mongo queries
 *   - 4c40f63 feat(auth): refresh-token rotation with replay revocation
 *   - password policy: reject common/weak passwords (auth.hardening docs)
 *   - rate limiting: structured 429 on /api/auth/login
 */

import bcrypt from "bcryptjs";
import { beforeEach, describe, expect, it, vi } from "vitest";
import request from "supertest";

vi.mock("../../src/modules/auth/auth.model.js", async () => {
  const { authModelMock } = await import("../helpers/authMocks.js");
  return authModelMock();
});

vi.mock("../../src/modules/auth/session.model.js", async () => {
  const { sessionModelMock } = await import("../helpers/authMocks.js");
  return sessionModelMock();
});

// The calendar routes reject malformed identifiers in validation middleware
// before any model call; no calendar.model mock is needed.

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { signAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const userModel = User as any;
const sessionModel = AuthSession as any;

const password = "Auxilia$ecure2026";
const passwordHashPromise = bcrypt.hash(password, 10);

const activeSession = (sessionId: string, userId: string) => ({
  _id: sessionId,
  userId,
  revokedAt: null as Date | null,
  expiresAt: new Date(Date.now() + 60 * 60 * 1000),
  userAgent: "vitest",
  createdAt: new Date(),
  lastUsedAt: new Date(),
});

const authenticate = (userId = "regression-user-1"): string => {
  const { token, sessionId } = signAccessToken(userId, "regression@example.com");
  userModel.findById.mockReturnValue(
    queryResult({ _id: userId, email: "regression@example.com", role: "user" }),
  );
  sessionModel.findById.mockReturnValue(
    queryResult(activeSession(sessionId, userId)),
  );
  return token;
};

beforeEach(() => {
  vi.resetAllMocks();
  sessionCache.clear();
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  sessionModel.updateOne.mockReturnValue(queryResult({}));
  sessionModel.updateMany.mockReturnValue(queryResult({}));
});

// ==========================================
// d81bd7a / f0d4369 — identifier validation before Mongo queries
// ==========================================

describe("regression: calendar identifier validation (d81bd7a, f0d4369)", () => {
  it("rejects a non-UUID groupId query with 400, not a Mongo error", async () => {
    const token = authenticate();

    const res = await request(app)
      .get(
        "/api/calendar?startDate=2027-01-01T00:00:00.000Z&endDate=2027-01-02T00:00:00.000Z&groupId=../../etc/passwd",
      )
      .set("Authorization", `Bearer ${token}`);

    expect(res.status).toBe(400);
  });

  it("rejects a non-UUID groupId on event creation with 400", async () => {
    const token = authenticate();

    const res = await request(app)
      .post("/api/calendar")
      .set("Authorization", `Bearer ${token}`)
      .send({
        title: "Injection probe",
        startTime: "2027-01-01T09:00:00.000Z",
        endTime: "2027-01-01T10:00:00.000Z",
        groupId: "1'; DROP TABLE users; --",
      });

    expect(res.status).toBe(400);
  });
});

// ==========================================
// 4c40f63 — refresh-token rotation replay protection
// ==========================================

describe("regression: refresh-token replay revocation (4c40f63)", () => {
  it("revokes the session when a superseded refresh token is replayed", async () => {
    const passwordHash = await passwordHashPromise;
    userModel.findOne.mockReturnValue(
      queryResult({
        _id: "regression-user-1",
        email: "ada@example.com",
        role: "user",
        passwordHash,
        lastLoginAt: null,
        save: vi.fn().mockResolvedValue(undefined),
      }),
    );

    // Log in to obtain a refresh token pair.
    const login = await request(app)
      .post("/api/auth/login")
      .send({ email: "ada@example.com", password });
    expect(login.status).toBe(200);

    const { parseRefreshToken, hashRefreshToken } = await import(
      "../../src/shared/utils/refreshTokens.js"
    );
    const original = parseRefreshToken(login.body.refreshToken)!;

    // Session row as it exists *after* a first refresh rotated the secret:
    // the current hash belongs to a NEW token, the previous hash belonged to
    // the ORIGINAL token, and the rotation happened long ago (outside the
    // replay grace window). Replaying the original token must trigger the
    // theft path: session revoked and 401 (4c40f63).
    const longAgo = new Date(Date.now() - 60 * 60 * 1000);
    sessionModel.findById.mockReturnValue(
      queryResult({
        ...activeSession(original.sessionId, "regression-user-1"),
        refreshTokenHash: hashRefreshToken("brand-new-secret-after-rotation"),
        previousRefreshTokenHash: hashRefreshToken(original.secret),
        refreshedAt: longAgo,
      }),
    );

    const replay = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken: login.body.refreshToken });

    expect(replay.status).toBe(401);
    expect(replay.body.code).toBe("UNAUTHORIZED");
    // The theft path revokes the session for this user…
    expect(sessionModel.updateOne).toHaveBeenCalledWith(
      { _id: original.sessionId, userId: "regression-user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } },
    );
  });
});

// ==========================================
// Password policy hardening — weak/common passwords rejected
// ==========================================

describe("regression: password policy (auth hardening)", () => {
  it.each([
    ["Password123!", "common"],
    ["short1!A", "12"],
    ["NOLOWERCASE1!", "lowercase"],
    ["NoSpecial123", "special character"],
  ])(
    "rejects %s with a 400 validation error",
    async (candidate) => {
      const res = await request(app)
        .post("/api/auth/signup")
        .send({
          name: "Ada",
          email: "policy@example.com",
          password: candidate,
        });

      expect(res.status).toBe(400);
      expect(res.body.code).toBe("VALIDATION_ERROR");
    },
  );
});

// ==========================================
// Rate limiting returns a structured 429
// ==========================================

describe("regression: auth rate limiter responds with structured 429", () => {
  it("middleware exposes the 429 contract (shape and code)", async () => {
    // The shared setup lifts rate limits for the suite; assert the
    // rate-limit middleware itself produces the documented structure by
    // mounting a constrained limiter on a probe app.
    const { default: express } = await import("express");
    const { createRateLimiter } = await import(
      "../../src/middleware/rateLimiter.js"
    );

    const probe = express();
    probe.use(
      "/probe",
      createRateLimiter({
        name: "regression",
        windowMs: 60_000,
        limit: 1,
        message: { error: "Too many requests, please try again later." },
      }),
    );
    probe.get("/probe", (_req, res) => res.json({ ok: true }));

    await request(probe).get("/probe");
    const limited = await request(probe).get("/probe");
    expect(limited.status).toBe(429);
    expect(limited.body.error).toMatch(/too many requests/i);
  });
});
