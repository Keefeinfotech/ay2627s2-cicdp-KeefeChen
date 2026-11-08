export const JWT_ISSUER = "auxilia-api";

export const USER_ROLES = ["user", "admin"] as const;

export type UserRole = (typeof USER_ROLES)[number];

export const AUTH_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;
export const AI_RATE_LIMIT_WINDOW_MS = 60 * 60 * 1000;
export const API_RATE_LIMIT_WINDOW_MS = 15 * 60 * 1000;

export const REQUEST_BODY_LIMIT = "10kb";

export const SESSION_TTL_MS = 24 * 60 * 60 * 1000;
