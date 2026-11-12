export const JWT_ISSUER = "auxilia-api";

export const USER_ROLES = ["user", "admin"] as const;

export type UserRole = (typeof USER_ROLES)[number];

export const AUTH_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
export const AI_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
export const API_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;

export const REQUEST_BODY_LIMIT = "10kb";

// Fallback refresh-token lifetime used when REFRESH_TOKEN_EXPIRES_IN is unset
// or cannot be parsed. Access tokens are far shorter-lived (JWT_EXPIRES_IN,
// default 15m) and are renewed silently with the refresh token.
export const REFRESH_TOKEN_TTL_MS = 30 * 24 * 60 * 60 * 1000;

// A rotated refresh token stays acceptable for this long so two refreshes that
// race in flight (same client, lost response) do not lock the user out. A
// superseded token replayed after this window is treated as stolen.
export const REFRESH_REUSE_GRACE_MS = 10 * 1000;
