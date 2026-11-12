import type { UserRole } from "../../constants/security.js";

export interface PublicUser {
  id: string;
  name?: string;
  email: string;
}

export interface AuthenticatedUser extends PublicUser {
  role: UserRole;
}

export interface AuthResult {
  token: string;
  /** Opaque refresh token; store it securely to renew `token` silently. */
  refreshToken: string;
  user: PublicUser;
}

/** One entry of `GET /api/auth/sessions`. */
export interface SessionSummary {
  id: string;
  /** True for the session that made this request. */
  current: boolean;
  userAgent: string | null;
  createdAt: Date;
  lastUsedAt: Date;
  expiresAt: Date;
}
