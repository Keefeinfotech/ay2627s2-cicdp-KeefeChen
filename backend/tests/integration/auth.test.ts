/*
 * File Name: auth.test.ts
 * Description: Integration tests for user authentication endpoints.
 * Author: Keefe Chen
 */

import bcrypt from "bcryptjs";
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
import { verifyAccessToken } from "../../src/shared/utils/tokens";

// Access mocked model methods.
const userModel = User as any;
const sessionModel = AuthSession as any;

// Query result helper supporting .exec().
const queryResult = (value: unknown) => ({
  select: vi.fn().mockReturnThis(),
  sort: vi.fn().mockReturnThis(),
  exec: vi.fn().mockResolvedValue(value),
});

// Shared test password and its hash. Meets the 12-character minimum and
// complexity rules (uppercase + number + special character).
const password = "Auxilia$ecure2026";
const passwordHashPromise = bcrypt.hash(password, 10);

// Reset mock call history before each test.
beforeEach(() => {
  vi.resetAllMocks();
  // Validations are cached in memory; drop any hit from a previous test.
  sessionCache.clear();
  // Default query chains so model calls the test does not stub still resolve.
  sessionModel.create.mockResolvedValue({});
  sessionModel.find.mockReturnValue(queryResult([]));
  sessionModel.findById.mockReturnValue(queryResult(null));
  sessionModel.updateOne.mockReturnValue(queryResult({}));
  sessionModel.updateMany.mockReturnValue(queryResult({}));
});

// ==========================================
// SIGNUP TESTS
// ==========================================

describe("POST /api/auth/signup", () => {
  it("creates an account and returns a signed session token", async () => {
    userModel.findOne.mockReturnValue(queryResult(null));

    // Mock the newly created user document.
    const created = {
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      save: vi.fn().mockResolvedValue(undefined),
    };

    userModel.create.mockResolvedValue(created);

    const res = await request(app).post("/api/auth/signup").send({
      name: "  Ada  ",
      email: "  ADA@Example.COM ",
      password,
    });

    // Verify successful account creation.
    expect(res.status).toBe(201);

    expect(res.body.user).toEqual({
      id: "user-1",
      name: "Ada",
      email: "ada@example.com",
    });
    expect(res.body.user).not.toHaveProperty("role");
    expect(userModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        email: "ada@example.com",
        name: "Ada",
      }),
    );

    // Verify the access token.
    const payload = verifyAccessToken(res.body.token);

    expect(payload?.sub).toBe("user-1");

    // Verify a refresh token bound to the same session was issued.
    expect(res.body.refreshToken).toMatch(new RegExp(`^${payload?.jti}\\.`));

    // Verify that a session row was created for this login.
    expect(sessionModel.create).toHaveBeenCalledWith(
      expect.objectContaining({
        _id: payload?.jti,
        userId: "user-1",
        refreshTokenHash: expect.any(String),
        expiresAt: expect.any(Date),
      }),
    );
    expect(created.save).toHaveBeenCalledTimes(1);
  });

  it("rejects an email that is already registered", async () => {
    userModel.findOne.mockReturnValue(queryResult({ _id: "existing" }));

    const res = await request(app).post("/api/auth/signup").send({
      email: "ada@example.com",
      password,
    });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe("CONFLICT");

    // Ensure that no new account was created.
    expect(userModel.create).not.toHaveBeenCalled();
  });

  it("maps a duplicate-key race to a conflict", async () => {
    userModel.findOne.mockReturnValue(queryResult(null));
    userModel.create.mockRejectedValue({
      name: "MongoServerError",
      code: 11000,
    });

    const res = await request(app).post("/api/auth/signup").send({
      email: "ada@example.com",
      password,
    });

    expect(res.status).toBe(409);
    expect(res.body.code).toBe("CONFLICT");
  });

  it("rejects unknown fields", async () => {
    const res = await request(app).post("/api/auth/signup").send({
      email: "ada@example.com",
      password,
      role: "admin",
    });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
    expect(userModel.create).not.toHaveBeenCalled();
  });

  it("rejects invalid input without echoing values", async () => {
    const res = await request(app).post("/api/auth/signup").send({
      email: "not-an-email",
      password: "secret-should-not-appear",
    });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");

    // Ensure sensitive input is not returned in the response.
    expect(JSON.stringify(res.body)).not.toContain("secret-should-not-appear");
  });

  it("rejects malformed JSON bodies", async () => {
    const res = await request(app)
      .post("/api/auth/signup")
      .set("Content-Type", "application/json")
      .send('{"email": ');

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("INVALID_JSON");
  });
});

// ==========================================
// PASSWORD STRENGTH TESTS
// ==========================================

describe("POST /api/auth/signup â€” password strength", () => {
  const baseSignup = {
    email: "strength@example.com",
    password: "StrongPass1!", // 12 chars, upper, lower, number, special
  };

  it.each([
    [
      "rejects a password shorter than 12 characters",
      "Short1!",
      "at least 12 characters",
    ],
    [
      "rejects a password without an uppercase letter",
      "nouppercase1!",
      "uppercase",
    ],
    [
      "rejects a password without a lowercase letter",
      "NOLOWERCASE1!",
      "lowercase",
    ],
    ["rejects a password without a number", "NoNumberHere!", "number"],
    [
      "rejects a password without a special character",
      "NoSpecial123",
      "special character",
    ],
  ])("%s", async (_testName, invalidPassword, expectedKeyword) => {
    const res = await request(app)
      .post("/api/auth/signup")
      .send({ ...baseSignup, password: invalidPassword });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
    expect(JSON.stringify(res.body.details)).toContain(expectedKeyword);
  });

  it("rejects a common password even when complex", async () => {
    userModel.findOne.mockImplementation(() => queryResult(null));

    const res = await request(app).post("/api/auth/signup").send({
      email: "common-password@example.com",
      password: "Password123!",
    });

    expect(res.status).toBe(400);
    expect(res.body.code).toBe("VALIDATION_ERROR");
    expect(JSON.stringify(res.body.details)).toContain("common");
  });

  it("accepts a strong password that meets all rules", async () => {
    userModel.findOne.mockImplementation(() => queryResult(null));
    userModel.create.mockImplementation(() =>
      Promise.resolve({
        _id: "user-1",
        name: "Ada",
        email: "strength@example.com",
        role: "user",
        save: vi.fn().mockResolvedValue(undefined),
      }),
    );

    const res = await request(app)
      .post("/api/auth/signup")
      .send({ ...baseSignup, password: "Auxilia$ecure2026" });

    expect(res.status).toBe(201);
  });
});

// ==========================================
// LOGIN TESTS
// ==========================================

describe("POST /api/auth/login", () => {
  it("returns a token and records the login time", async () => {
    const save = vi.fn().mockResolvedValue(undefined);

    const user = {
      _id: "user-1",
      name: "Ada",
      email: "ada@example.com",
      role: "user",
      passwordHash: await passwordHashPromise,
      lastLoginAt: null as Date | null,
      save,
    };

    userModel.findOne.mockReturnValue(queryResult(user));

    const res = await request(app).post("/api/auth/login").send({
      email: "ADA@example.com",
      password,
    });

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe("ada@example.com");

    // Verify the returned access token.
    const payload = verifyAccessToken(res.body.token);
    expect(payload?.email).toBe("ada@example.com");

    // A session row with a refresh token backs this login.
    expect(res.body.refreshToken).toMatch(new RegExp(`^${payload?.jti}\\.`));
    expect(sessionModel.create).toHaveBeenCalledWith(
      expect.objectContaining({ _id: payload?.jti, userId: "user-1" }),
    );
    // Concurrent sessions are disabled by default: older devices are revoked.
    expect(sessionModel.updateMany).toHaveBeenCalledWith(
      { userId: "user-1", _id: { $ne: payload?.jti }, revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } },
    );

    // Verify that the login timestamp was updated.
    expect(save).toHaveBeenCalledTimes(1);
    expect(user.lastLoginAt).toBeInstanceOf(Date);
  });

  it("rejects a wrong password", async () => {
    userModel.findOne.mockReturnValue(
      queryResult({
        _id: "user-1",
        email: "ada@example.com",
        role: "user",
        passwordHash: await passwordHashPromise,
        save: vi.fn(),
      }),
    );

    const res = await request(app).post("/api/auth/login").send({
      email: "ada@example.com",
      password: "wrong-password",
    });

    expect(res.status).toBe(401);
    expect(res.body.code).toBe("UNAUTHORIZED");
  });

  it("rejects an unknown account with the same message", async () => {
    userModel.findOne.mockReturnValue(queryResult(null));

    const res = await request(app).post("/api/auth/login").send({
      email: "nobody@example.com",
      password,
    });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe("Invalid email or password");
  });
});

// ==========================================
// PASSWORD RESET TESTS
// ==========================================

describe("POST /api/auth/forgot-password", () => {
  it("returns the generic message when the address is registered", async () => {
    const doc: Record<string, unknown> = {
      _id: "user-1",
      email: "ada@example.com",
      role: "user",
      save: vi.fn().mockResolvedValue(undefined),
    };
    userModel.findOne.mockReturnValue(queryResult(doc));

    const res = await request(app)
      .post("/api/auth/forgot-password")
      .send({ email: "ada@example.com" });

    expect(res.status).toBe(200);
    expect(res.body.message).toContain("If an account exists");

    // A reset token must be generated and stored on the mocked document.
    expect(doc.save).toHaveBeenCalledTimes(1);
    expect(doc.passwordResetTokenHash).toBeTruthy();
    expect(doc.passwordResetExpiresAt).toBeInstanceOf(Date);
  });

  it("returns the same message when the address is not registered", async () => {
    userModel.findOne.mockReturnValue(queryResult(null));

    const res = await request(app)
      .post("/api/auth/forgot-password")
      .send({ email: "nobody@example.com" });

    expect(res.status).toBe(200);
    expect(res.body.message).toContain("If an account exists");
  });

  it("rejects a malformed email address", async () => {
    const res = await request(app)
      .post("/api/auth/forgot-password")
      .send({ email: "nope" });

    expect(res.status).toBe(400);
  });
});

describe("POST /api/auth/reset-password", () => {
  // Shared new password that meets the 12-character minimum and complexity rules.
  const newPassword = "N3w$ecurePassword";

  it("updates the password and revokes every session when the token is valid", async () => {
    const doc: Record<string, unknown> = {
      _id: "user-1",
      email: "ada@example.com",
      role: "user",
      passwordHash: "old-hash",
      passwordResetTokenHash: "stored-hash",
      passwordResetExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
      save: vi.fn().mockResolvedValue(undefined),
    };
    userModel.findOne.mockReturnValue(queryResult(doc));

    const res = await request(app)
      .post("/api/auth/reset-password")
      .send({ token: "reset-token", password: newPassword });

    expect(res.status).toBe(200);
    expect(doc.passwordResetTokenHash).toBeNull();
    expect(doc.passwordResetExpiresAt).toBeNull();
    expect(doc.passwordHash).not.toBe("old-hash");
    expect(doc.passwordHash).toBeTruthy();

    // Every session is revoked so a stolen password cannot keep one.
    expect(sessionModel.updateMany).toHaveBeenCalledWith(
      { userId: "user-1", revokedAt: null },
      { $set: { revokedAt: expect.any(Date) } },
    );
  });

  it("rejects an expired link", async () => {
    userModel.findOne.mockReturnValue(
      queryResult({
        _id: "user-1",
        email: "ada@example.com",
        passwordResetTokenHash: "old-hash",
        passwordResetExpiresAt: new Date(Date.now() - 1000),
        save: vi.fn(),
      }),
    );

    const res = await request(app)
      .post("/api/auth/reset-password")
      .send({ token: "reset-token", password: newPassword });

    expect(res.status).toBe(400);
  });

  it("rejects an unknown link", async () => {
    userModel.findOne.mockReturnValue(queryResult(null));

    const res = await request(app)
      .post("/api/auth/reset-password")
      .send({ token: "reset-token", password: newPassword });

    expect(res.status).toBe(400);
  });

  it("rejects a weak password", async () => {
    const res = await request(app)
      .post("/api/auth/reset-password")
      .send({ token: "reset-token", password: "short" });

    expect(res.status).toBe(400);
  });
});
