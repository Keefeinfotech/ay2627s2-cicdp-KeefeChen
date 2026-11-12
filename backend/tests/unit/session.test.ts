import { describe, expect, it } from "vitest";
import {
  isSessionExpired,
  isSessionRevoked,
  parseDurationToMs,
} from "../../src/shared/utils/session";

const future = new Date(Date.now() + 60_000);
const past = new Date(Date.now() - 60_000);

describe("parseDurationToMs", () => {
  it("parses common JWT-style durations", () => {
    expect(parseDurationToMs("15m")).toBe(15 * 60 * 1000);
    expect(parseDurationToMs("30m")).toBe(30 * 60 * 1000);
    expect(parseDurationToMs("12h")).toBe(12 * 60 * 60 * 1000);
    expect(parseDurationToMs("30d")).toBe(30 * 24 * 60 * 60 * 1000);
    expect(parseDurationToMs("1d")).toBe(24 * 60 * 60 * 1000);
  });

  it("returns null for missing or unsupported values", () => {
    expect(parseDurationToMs(undefined)).toBeNull();
    expect(parseDurationToMs("")).toBeNull();
    expect(parseDurationToMs("soon")).toBeNull();
    expect(parseDurationToMs("5w")).toBeNull();
  });
});

describe("isSessionRevoked", () => {
  it("accepts a session that was never revoked", () => {
    expect(isSessionRevoked({ revokedAt: null })).toBe(false);
    expect(isSessionRevoked({})).toBe(false);
  });

  it("rejects an explicitly revoked session", () => {
    expect(isSessionRevoked({ revokedAt: past })).toBe(true);
    expect(isSessionRevoked({ revokedAt: past.toISOString() })).toBe(true);
  });

  it("treats any present revocation timestamp as revoked", () => {
    expect(isSessionRevoked({ revokedAt: "not-a-date" })).toBe(true);
    expect(isSessionRevoked({ revokedAt: new Date(NaN) })).toBe(true);
  });
});

describe("isSessionExpired", () => {
  it("accepts a session with a future deadline", () => {
    expect(isSessionExpired({ expiresAt: future })).toBe(false);
    expect(isSessionExpired({ expiresAt: future.toISOString() })).toBe(false);
  });

  it("rejects a session past its deadline", () => {
    expect(isSessionExpired({ expiresAt: past })).toBe(true);
    expect(isSessionExpired({ expiresAt: past.toISOString() })).toBe(true);
  });

  it("rejects a session whose deadline is exactly now", () => {
    const now = new Date();
    expect(isSessionExpired({ expiresAt: now }, now)).toBe(true);
  });

  it("fails closed when the deadline is missing or unparseable", () => {
    expect(isSessionExpired({})).toBe(true);
    expect(isSessionExpired({ expiresAt: null })).toBe(true);
    expect(isSessionRevoked({ expiresAt: "garbage" })).toBe(false);
    expect(isSessionExpired({ expiresAt: "garbage" })).toBe(true);
  });

  it("uses the current time when no clock is supplied", () => {
    expect(isSessionExpired({ expiresAt: future })).toBe(false);
    expect(isSessionExpired({ expiresAt: past })).toBe(true);
  });
});
