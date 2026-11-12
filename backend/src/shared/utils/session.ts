// Session rules for the API.
//
// Every login creates a row in the auth sessions collection:
//   - the session id doubles as the JWT id (jti)
//   - refresh tokens are opaque secrets bound to that session
//   - a session can be revoked individually (device sign-out), which ends
//     every access token issued for it
//
// The pure helpers below have no dependencies so they can be unit tested
// without MongoDB.

const DURATION_PATTERN = /^(\d+)\s*(ms|s|m|h|d)$/i;

const UNIT_TO_MS: Record<string, number> = {
  ms: 1,
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
};

/**
 * Converts a short duration such as "1d", "12h", "30m" into milliseconds.
 * Returns null when the value cannot be understood so callers can fall back.
 */
export const parseDurationToMs = (value: string | undefined): number | null => {
  if (!value) return null;
  const match = DURATION_PATTERN.exec(value.trim());
  if (!match) return null;
  const amount = Number(match[1]);
  const unit = match[2].toLowerCase();
  return amount * UNIT_TO_MS[unit];
};

export interface SessionRecord {
  expiresAt?: Date | string | null;
  revokedAt?: Date | string | null;
}

const toDate = (value: Date | string | null | undefined): Date | null => {
  if (value === null || value === undefined) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

/** True once the session has been explicitly revoked (logout, device sign-out,
 *  a newer login when concurrent sessions are disabled, or refresh-token
 *  reuse). A present but unparseable timestamp counts as revoked so a corrupt
 *  row fails closed. */
export const isSessionRevoked = (record: SessionRecord): boolean => {
  if (record.revokedAt === null || record.revokedAt === undefined) {
    return false;
  }
  // Any present value counts as revoked: a corrupt timestamp must fail
  // closed rather than silently reopening the session.
  return true;
};

/** True when the session has passed its refresh-token deadline. A missing or
 *  unparseable deadline counts as expired so a corrupt row fails closed. */
export const isSessionExpired = (
  record: SessionRecord,
  now: Date = new Date(),
): boolean => {
  const expiresAt = toDate(record.expiresAt);
  if (!expiresAt) return true;
  return expiresAt.getTime() <= now.getTime();
};
