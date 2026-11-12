// Opaque refresh tokens.
//
// Format: `<sessionId>.<secret>`. The session id lets the API find the session
// row with a single indexed lookup; only sha256(secret) is stored, so a token
// leaked from storage or logs cannot be replayed without the session row.

import { createHash, randomBytes, timingSafeEqual } from "node:crypto";

const REFRESH_SECRET_BYTES = 48;
const MIN_SECRET_LENGTH = 32;
const MAX_SESSION_ID_LENGTH = 128;

export interface RefreshTokenParts {
  sessionId: string;
  secret: string;
}

export interface IssuedRefreshToken {
  token: string;
  /** Value persisted on the session row; never store the raw token. */
  hash: string;
}

export const hashRefreshToken = (secret: string): string =>
  createHash("sha256").update(secret).digest("hex");

/** Generates a fresh refresh token bound to the given session id. */
export const generateRefreshToken = (sessionId: string): IssuedRefreshToken => {
  const secret = randomBytes(REFRESH_SECRET_BYTES).toString("base64url");
  return { token: `${sessionId}.${secret}`, hash: hashRefreshToken(secret) };
};

/** Splits a presented refresh token, or returns null when it is malformed. */
export const parseRefreshToken = (token: string): RefreshTokenParts | null => {
  const separator = token.indexOf(".");
  if (separator <= 0) return null;

  const sessionId = token.slice(0, separator);
  const secret = token.slice(separator + 1);

  if (sessionId.length > MAX_SESSION_ID_LENGTH) return null;
  if (secret.length < MIN_SECRET_LENGTH) return null;

  return { sessionId, secret };
};

/**
 * Constant-time comparison of a presented secret against a stored hash.
 * Returns false for empty/absent hashes instead of throwing.
 */
export const refreshTokenHashMatches = (
  presentedSecret: string,
  storedHash: string | null | undefined
): boolean => {
  if (!storedHash) return false;

  const presented = Buffer.from(hashRefreshToken(presentedSecret), "utf8");
  const stored = Buffer.from(storedHash, "utf8");

  if (presented.length !== stored.length) return false;
  return timingSafeEqual(presented, stored);
};
