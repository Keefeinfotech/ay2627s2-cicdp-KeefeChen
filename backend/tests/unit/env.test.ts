import { afterEach, describe, expect, it } from "vitest";
import {
  EnvError,
  getBcryptRounds,
  getJwtExpiresIn,
  getJwtSecret,
} from "../../src/config/environment";

const originalSecret = process.env.JWT_SECRET;
const originalRounds = process.env.BCRYPT_ROUNDS;
const originalExpiry = process.env.JWT_EXPIRES_IN;

afterEach(() => {
  process.env.JWT_SECRET = originalSecret;
  process.env.BCRYPT_ROUNDS = originalRounds;
  process.env.JWT_EXPIRES_IN = originalExpiry;
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

  it("defaults the token expiry when unset", () => {
    delete process.env.JWT_EXPIRES_IN;
    expect(getJwtExpiresIn()).toBe("1d");
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
