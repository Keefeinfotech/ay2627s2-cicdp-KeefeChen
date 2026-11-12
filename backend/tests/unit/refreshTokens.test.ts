import { describe, expect, it } from "vitest";
import {
  generateRefreshToken,
  hashRefreshToken,
  parseRefreshToken,
  refreshTokenHashMatches,
} from "../../src/shared/utils/refreshTokens";

describe("generateRefreshToken", () => {
  it("produces a sessionId.secret token bound to the session", () => {
    const issued = generateRefreshToken("session-1");
    const parts = parseRefreshToken(issued.token);

    expect(parts).not.toBeNull();
    expect(parts?.sessionId).toBe("session-1");
    expect(parts?.secret.length).toBeGreaterThanOrEqual(32);
  });

  it("stores only the sha256 of the secret", () => {
    const issued = generateRefreshToken("session-1");
    const parts = parseRefreshToken(issued.token)!;

    expect(issued.hash).toBe(hashRefreshToken(parts.secret));
    expect(issued.hash).not.toContain(parts.secret);
    expect(issued.token).not.toBe(issued.hash);
  });

  it("never repeats a secret", () => {
    const first = generateRefreshToken("session-1");
    const second = generateRefreshToken("session-1");
    expect(first.token).not.toBe(second.token);
  });
});

describe("parseRefreshToken", () => {
  it("splits a well-formed token", () => {
    const secret = "s".repeat(48);
    expect(parseRefreshToken(`abc.${secret}`)).toEqual({
      sessionId: "abc",
      secret,
    });
  });

  it("rejects malformed tokens", () => {
    expect(parseRefreshToken("")).toBeNull();
    expect(parseRefreshToken("no-secret")).toBeNull();
    expect(parseRefreshToken(".leading-dot")).toBeNull();
    expect(parseRefreshToken("session.short")).toBeNull(); // secret < 32 chars
    expect(parseRefreshToken(`${"x".repeat(200)}.secret`)).toBeNull();
  });
});

describe("refreshTokenHashMatches", () => {
  const secret = "a".repeat(48);
  const hash = hashRefreshToken(secret);

  it("matches the correct secret against its hash", () => {
    expect(refreshTokenHashMatches(secret, hash)).toBe(true);
  });

  it("rejects a wrong secret", () => {
    expect(refreshTokenHashMatches("b".repeat(48), hash)).toBe(false);
  });

  it("rejects an absent stored hash without throwing", () => {
    expect(refreshTokenHashMatches(secret, null)).toBe(false);
    expect(refreshTokenHashMatches(secret, undefined)).toBe(false);
    expect(refreshTokenHashMatches(secret, "")).toBe(false);
  });
});
