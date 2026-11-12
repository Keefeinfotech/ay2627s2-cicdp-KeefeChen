import { afterEach, describe, expect, it } from "vitest";
import {
  EnvError,
  getBcryptRounds,
  getJwtExpiresIn,
  getJwtSecret,
  getPort,
} from "../../src/config/environment";

const originalSecret = process.env.JWT_SECRET;
const originalRounds = process.env.BCRYPT_ROUNDS;
const originalExpiry = process.env.JWT_EXPIRES_IN;
const originalPort = process.env.PORT;

afterEach(() => {
  process.env.JWT_SECRET = originalSecret;
  process.env.BCRYPT_ROUNDS = originalRounds;
  process.env.JWT_EXPIRES_IN = originalExpiry;
  if (originalPort === undefined) {
    delete process.env.PORT;
  } else {
    process.env.PORT = originalPort;
  }
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

  it("resolves the port Render injects for web services", () => {
    process.env.PORT = "10000";
    expect(getPort()).toBe(10000);
  });

  it("falls back to 3000 when PORT is unset or invalid", () => {
    delete process.env.PORT;
    expect(getPort()).toBe(3000);

    process.env.PORT = "not-a-number";
    expect(getPort()).toBe(3000);

    process.env.PORT = "70000";
    expect(getPort()).toBe(3000);
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
