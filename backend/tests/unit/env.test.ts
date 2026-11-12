import { afterEach, describe, expect, it } from "vitest";
import {
  EnvError,
  getBcryptRounds,
  getJwtExpiresIn,
  getJwtSecret,
  getRefreshTokenExpiresIn,
  getSessionCacheTtlMs,
} from "../../src/config/environment";

const originalSecret = process.env.JWT_SECRET;
const originalRounds = process.env.BCRYPT_ROUNDS;
const originalExpiry = process.env.JWT_EXPIRES_IN;
const originalRefreshExpiry = process.env.REFRESH_TOKEN_EXPIRES_IN;
const originalCacheTtl = process.env.SESSION_CACHE_TTL_MS;

afterEach(() => {
  process.env.JWT_SECRET = originalSecret;
  process.env.BCRYPT_ROUNDS = originalRounds;
  process.env.JWT_EXPIRES_IN = originalExpiry;
  process.env.REFRESH_TOKEN_EXPIRES_IN = originalRefreshExpiry;
  process.env.SESSION_CACHE_TTL_MS = originalCacheTtl;
});

describe("environment configuration", () => {
  it("returns the configured JWT secret", () => {
    process.env.JWT_SECRET = "a-secret-that-is-long-enough";
    expect(getJwtSecret()).toBe("a-secret-that-is-long-enough");
  });

  it("rejects a missing JWT secret", () => {
    delete process.env.JWT_SECRET;
    expect(() => getJwtSecret()).toThrow(EnvError);
  });

  it("rejects a short JWT secret", () => {
    process.env.JWT_SECRET = "too-short";
    expect(() => getJwtSecret()).toThrow(EnvError);
  });

  it("defaults the access-token expiry to 15 minutes", () => {
    delete process.env.JWT_EXPIRES_IN;
    expect(getJwtExpiresIn()).toBe("15m");
  });

  it("returns a configured access-token expiry", () => {
    process.env.JWT_EXPIRES_IN = "5m";
    expect(getJwtExpiresIn()).toBe("5m");
  });

  it("defaults the refresh-token expiry to 30 days", () => {
    delete process.env.REFRESH_TOKEN_EXPIRES_IN;
    expect(getRefreshTokenExpiresIn()).toBe("30d");
  });

  it("returns a configured refresh-token expiry", () => {
    process.env.REFRESH_TOKEN_EXPIRES_IN = "7d";
    expect(getRefreshTokenExpiresIn()).toBe("7d");
  });

  it("defaults the session cache TTL to 30 seconds", () => {
    delete process.env.SESSION_CACHE_TTL_MS;
    expect(getSessionCacheTtlMs()).toBe(30_000);
  });

  it("accepts an explicit session cache TTL including 0", () => {
    process.env.SESSION_CACHE_TTL_MS = "0";
    expect(getSessionCacheTtlMs()).toBe(0);

    process.env.SESSION_CACHE_TTL_MS = "5000";
    expect(getSessionCacheTtlMs()).toBe(5_000);
  });

  it("rejects out-of-range or malformed session cache TTLs", () => {
    process.env.SESSION_CACHE_TTL_MS = "-1";
    expect(getSessionCacheTtlMs()).toBe(30_000);

    process.env.SESSION_CACHE_TTL_MS = "600001";
    expect(getSessionCacheTtlMs()).toBe(30_000);

    process.env.SESSION_CACHE_TTL_MS = "soon";
    expect(getSessionCacheTtlMs()).toBe(30_000);
  });

  it("clamps bcrypt rounds to a safe range", () => {
    process.env.BCRYPT_ROUNDS = "999";
    expect(getBcryptRounds()).toBe(15);

    process.env.BCRYPT_ROUNDS = "1";
    expect(getBcryptRounds()).toBe(10);

    process.env.BCRYPT_ROUNDS = "not-a-number";
    expect(getBcryptRounds()).toBe(10);
  });
});
