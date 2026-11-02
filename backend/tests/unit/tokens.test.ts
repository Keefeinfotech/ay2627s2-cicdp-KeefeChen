import jwt from "jsonwebtoken";
import { describe, expect, it } from "vitest";
import {
  signAccessToken,
  verifyAccessToken,
} from "../../src/shared/utils/tokens";

describe("access tokens", () => {
  it("round-trips a signed token with a session id", () => {
    const { token, sessionId } = signAccessToken(
      "user-1",
      "user@example.com",
      "session-1"
    );
    const payload = verifyAccessToken(token);

    expect(payload).not.toBeNull();
    expect(payload?.sub).toBe("user-1");
    expect(payload?.email).toBe("user@example.com");
    expect(payload?.jti).toBe("session-1");
    expect(sessionId).toBe("session-1");
  });

  it("generates a unique session id when none is supplied", () => {
    const first = signAccessToken("user-1", "user@example.com");
    const second = signAccessToken("user-1", "user@example.com");
    expect(first.sessionId).not.toBe(second.sessionId);
  });

  it("rejects a tampered token", () => {
    const { token } = signAccessToken("user-1", "user@example.com");
    const tampered = `${token.slice(0, -2)}xx`;
    expect(verifyAccessToken(tampered)).toBeNull();
  });

  it("rejects an expired token", () => {
    const token = jwt.sign(
      { email: "user@example.com" },
      process.env.JWT_SECRET as string,
      { subject: "user-1", jwtid: "jti-1", issuer: "auxilia-api", expiresIn: "-1s" }
    );
    expect(verifyAccessToken(token)).toBeNull();
  });

  it("rejects a token from another issuer", () => {
    const token = jwt.sign(
      { email: "user@example.com" },
      process.env.JWT_SECRET as string,
      { subject: "user-1", jwtid: "jti-1", issuer: "someone-else", expiresIn: "1h" }
    );
    expect(verifyAccessToken(token)).toBeNull();
  });

  it("rejects an unsigned token", () => {
    const token = jwt.sign({ email: "user@example.com" }, "wrong-secret-value-123456");
    expect(verifyAccessToken(token)).toBeNull();
  });
});
