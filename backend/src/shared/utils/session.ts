// Session rules for the API.
//
// Enterprise APIs usually enforce "one active session per user" (or a small cap).
// We keep it intentionally simple and testable:
//   - every login gets a unique JWT id (jti)
//   - the newest jti is persisted on the user document
//   - any token whose jti no longer matches is rejected as "replaced"
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
  activeSessionId?: string | null;
  activeSessionExpiresAt?: Date | string | null;
}

/**
 * Returns true only when the presented token still represents the user's
 * active session and that session has not expired.
 */
export const isSessionActive = (
  record: SessionRecord,
  tokenJti: string | undefined,
  now: Date = new Date()
): boolean => {
  if (!tokenJti) return false;
  if (!record.activeSessionId) return false;
  if (record.activeSessionId !== tokenJti) return false;

  if (record.activeSessionExpiresAt) {
    const expiresAt =
      record.activeSessionExpiresAt instanceof Date
        ? record.activeSessionExpiresAt
        : new Date(record.activeSessionExpiresAt);
    if (Number.isNaN(expiresAt.getTime())) return false;
    if (expiresAt.getTime() <= now.getTime()) return false;
  }

  return true;
};
