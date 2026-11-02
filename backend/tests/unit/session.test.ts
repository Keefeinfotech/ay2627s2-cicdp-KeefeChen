import { describe, expect, it } from "vitest";
import { isSessionActive, parseDurationToMs } from "../../src/shared/utils/session";

const future = new Date(Date.now() + 60_000);
const past = new Date(Date.now() - 60_000);

describe("parseDurationToMs", () => {
  it("parses common JWT-style durations", () => {
    expect(parseDurationToMs("30m")).toBe(30 * 60 * 1000);
    expect(parseDurationToMs("12h")).toBe(12 * 60 * 60 * 1000);
    expect(parseDurationToMs("1d")).toBe(24 * 60 * 60 * 1000);
  });

  it("returns null for missing or unsupported values", () => {
    expect(parseDurationToMs(undefined)).toBeNull();
    expect(parseDurationToMs("")).toBeNull();
    expect(parseDurationToMs("soon")).toBeNull();
  });
});

describe("isSessionActive", () => {
  const active = { activeSessionId: "session-1", activeSessionExpiresAt: future };

  it("accepts the current, unexpired session", () => {
    expect(isSessionActive(active, "session-1")).toBe(true);
  });

  it("rejects an older session id (concurrent login)", () => {
    expect(isSessionActive(active, "session-old")).toBe(false);
  });

  it("rejects when no token jti is present", () => {
    expect(isSessionActive(active, undefined)).toBe(false);
  });

  it("rejects when the user has no active session", () => {
    expect(
      isSessionActive({ activeSessionId: null }, "session-1")
    ).toBe(false);
  });

  it("rejects an expired session even if the id matches", () => {
    expect(
      isSessionActive(
        { activeSessionId: "session-1", activeSessionExpiresAt: past },
        "session-1"
      )
    ).toBe(false);
  });

  it("accepts a session without an expiry timestamp", () => {
    expect(
      isSessionActive({ activeSessionId: "session-1" }, "session-1")
    ).toBe(true);
  });

  it("accepts ISO date strings from the database", () => {
    const record = {
      activeSessionId: "session-1",
      activeSessionExpiresAt: future.toISOString(),
    };
    expect(isSessionActive(record, "session-1")).toBe(true);
  });
});
