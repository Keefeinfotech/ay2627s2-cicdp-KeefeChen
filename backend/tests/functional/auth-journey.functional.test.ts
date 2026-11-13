/*
 * File Name: auth-journey.functional.test.ts
 * Description: Functional test for the complete authentication journey a real
 *   client takes: sign up, load the profile, refresh the session, list
 *   sessions, log out, and confirm the account is unusable afterwards with
 *   the same token. Assertions cover only what a black-box client can
 *   observe over HTTP.
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

import app from "../../src/app";
import { User } from "../../src/modules/auth/auth.model.js";
import { AuthSession } from "../../src/modules/auth/session.model.js";
import { sessionCache } from "../../src/modules/auth/session.cache.js";
import { verifyAccessToken } from "../../src/shared/utils/tokens";
import { queryResult } from "../helpers/authMocks.js";

const userModel = User as any;
const sessionModel = AuthSession as any;

const password = "Auxilia$ecure2026";
const passwordHashPromise = bcrypt.hash(password, 10);

const passwordValidationUser = {
  _id: "functional-user-1",
  name: "Ada",
  email: "ada@example.com",
  role: "user",
  save: vi.fn().mockResolvedValue(undefined),
};

const activeSession = (sessionId: string, userId: string) => ({
  _id: sessionId,
  userId,
  revokedAt: null as Date | null,
  expiresAt: new Date(Date.now() + 60 * 60 * 1000),
  userAgent: "vitest",
  createdAt: new Date(),
  lastUsedAt: new Date(),
});

beforeEach(() => {
  vi.resetAllMocks();
  sessionCache.clear();
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  sessionModel.updateOne.mockReturnValue(queryResult({}));
  sessionModel.updateMany.mockReturnValue(queryResult({}));
});

describe("authentication journey (functional)", () => {
  it("signup → me → refresh → sessions → logout → token rejected", async () => {
    // 1. Sign up.
    userModel.findOne.mockReturnValue(queryResult(null));
    userModel.create.mockResolvedValue({ ...passwordValidationUser });

    const signup = await request(app).post("/api/auth/signup").send({
      name: "Ada",
      email: "ada@example.com",
      password,
    });
    expect(signup.status).toBe(201);
    const accessToken: string = signup.body.token;
    const refreshToken: string = signup.body.refreshToken;
    expect(accessToken).toBeTruthy();
    expect(refreshToken).toBeTruthy();

    const payload = verifyAccessToken(accessToken);
    expect(payload?.sub).toBe("functional-user-1");

    // 2. Fetch the profile with the issued token.
    userModel.findById.mockReturnValue(
      queryResult({
        _id: "functional-user-1",
        email: "ada@example.com",
        name: "Ada",
        role: "user",
      }),
    );
    sessionModel.findById.mockReturnValue(
      queryResult(activeSession(payload!.jti, "functional-user-1")),
    );

    const me = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(me.status).toBe(200);
    expect(me.body.user?.email ?? me.body.email).toBe("ada@example.com");

    // 3. Refresh the session. The live session must be found for rotation.
    // The refresh flow re-hashes the presented secret and compares it
    // against the stored hash; reuse the real utilities.
    const { hashRefreshToken, parseRefreshToken } = await import(
      "../../src/shared/utils/refreshTokens.js"
    );
    const refreshParts = parseRefreshToken(refreshToken)!;
    const storedHash = hashRefreshToken(refreshParts.secret);
    sessionModel.findById.mockReturnValue(
      queryResult({
        ...activeSession(payload!.jti, "functional-user-1"),
        refreshTokenHash: storedHash,
      }),
    );
    userModel.findById.mockReturnValue(
      queryResult({
        _id: "functional-user-1",
        email: "ada@example.com",
        role: "user",
      }),
    );

    const refreshed = await request(app)
      .post("/api/auth/refresh")
      .send({ refreshToken });
    // Refresh succeeds with valid rotation semantics.
    expect(refreshed.status).toBe(200);
    expect(refreshed.body.token).toBeTruthy();

    // 4. List active sessions.
    sessionModel.find.mockReturnValue(
      queryResult([activeSession(payload!.jti, "functional-user-1")]),
    );
    const sessions = await request(app)
      .get("/api/auth/sessions")
      .set("Authorization", `Bearer ${accessToken}`);
    expect(sessions.status).toBe(200);

    // 5. Log out.
    const logout = await request(app)
      .post("/api/auth/logout")
      .set("Authorization", `Bearer ${accessToken}`);
    expect([200, 204]).toContain(logout.status);

    // 6. A revoked session id is treated as revoked by subsequent checks.
    sessionModel.findById.mockReturnValue(
      queryResult({
        ...activeSession(payload!.jti, "functional-user-1"),
        revokedAt: new Date(),
      }),
    );
    sessionCache.clear();
    const afterLogout = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${accessToken}`);
    expect([401, 403]).toContain(afterLogout.status);
  });

  it("login with correct credentials returns a usable token", async () => {
    const user = {
      _id: "functional-user-2",
      name: "Grace",
      email: "grace@example.com",
      role: "user",
      passwordHash: await passwordHashPromise,
      lastLoginAt: null as Date | null,
      save: vi.fn().mockResolvedValue(undefined),
    };
    userModel.findOne.mockReturnValue(queryResult(user));

    const login = await request(app).post("/api/auth/login").send({
      email: "grace@example.com",
      password,
    });
    expect(login.status).toBe(200);
    expect(login.body.token).toBeTruthy();

    const payload = verifyAccessToken(login.body.token);
    sessionModel.findById.mockReturnValue(
      queryResult(activeSession(payload!.jti, "functional-user-2")),
    );
    userModel.findById.mockReturnValue(
      queryResult({
        _id: "functional-user-2",
        email: "grace@example.com",
        name: "Grace",
        role: "user",
      }),
    );
    const me = await request(app)
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${login.body.token}`);
    expect(me.status).toBe(200);
  });
});
