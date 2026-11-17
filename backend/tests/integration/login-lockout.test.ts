/*
 * File Name: login-lockout.test.ts
 * Description: Account lockout on consecutive failed logins (OWASP A07).
 *              After LOGIN_LOCKOUT_MAX_ATTEMPTS consecutive failures the
 *              account locks for LOGIN_LOCKOUT_DURATION_MS and rejects even
 *              the correct password until the lock expires.
 */

import bcrypt from "bcryptjs";
import request from "supertest";
import { beforeEach, describe, expect, it, vi } from "vitest";

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
import { queryResult } from "../helpers/authMocks.js";
import {
  LOGIN_LOCKOUT_DURATION_MS,
  LOGIN_LOCKOUT_MAX_ATTEMPTS,
} from "../../src/constants/security";

const userModel = User as any;
const sessionModel = AuthSession as any;

const password = "Auxilia$ecure2026";
const passwordHashPromise = bcrypt.hash(password, 10);

beforeEach(() => {
  vi.resetAllMocks();
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  sessionModel.findById.mockReturnValue(queryResult(null));
  sessionModel.updateOne.mockReturnValue(queryResult({}));
  sessionModel.updateMany.mockReturnValue(queryResult({}));
});

const buildUser = async () => ({
  _id: "user-lockout",
  name: "Lock Test",
  email: "lock@example.com",
  role: "user",
  passwordHash: await passwordHashPromise,
  lastLoginAt: null as Date | null,
  failedLoginAttempts: 0,
  lockoutUntil: null as Date | null,
  save: vi.fn().mockResolvedValue(undefined),
});

describe("POST /api/auth/login - account lockout", () => {
  it("locks the account after the configured number of failed attempts", async () => {
    const user = await buildUser();
    userModel.findOne.mockReturnValue(queryResult(user));

    for (let attempt = 0; attempt < LOGIN_LOCKOUT_MAX_ATTEMPTS; attempt++) {
      const res = await request(app)
        .post("/api/auth/login")
        .send({ email: "lock@example.com", password: "wrong-password" });
      expect(res.status).toBe(401);
    }

    // Counter reset and lock expiry recorded on the account.
    expect(user.failedLoginAttempts).toBe(0);
    expect(user.lockoutUntil).toBeInstanceOf(Date);
    expect(user.lockoutUntil!.getTime()).toBeGreaterThan(Date.now());
    expect(user.lockoutUntil!.getTime()).toBeLessThanOrEqual(
      Date.now() + LOGIN_LOCKOUT_DURATION_MS,
    );
  });

  it("rejects even the correct password while the account is locked", async () => {
    const user = await buildUser();
    user.lockoutUntil = new Date(Date.now() + 10 * 60_000);
    userModel.findOne.mockReturnValue(queryResult(user));

    const res = await request(app)
      .post("/api/auth/login")
      .send({ email: "lock@example.com", password });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe("Invalid email or password");
    // A locked attempt must not create a session.
    expect(sessionModel.create).not.toHaveBeenCalled();
  });

  it("resets the failure counter on a successful login", async () => {
    const user = await buildUser();
    user.failedLoginAttempts = 3;
    userModel.findOne.mockReturnValue(queryResult(user));

    const res = await request(app)
      .post("/api/auth/login")
      .send({ email: "lock@example.com", password });

    expect(res.status).toBe(200);
    expect(user.failedLoginAttempts).toBe(0);
  });
});
