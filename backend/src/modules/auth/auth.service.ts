import { createHash, randomBytes } from "node:crypto";

import bcrypt from "bcryptjs";

import {
  allowConcurrentSessions,
  getAppBaseUrl,
  getBcryptRounds,
  getRefreshTokenExpiresIn,
} from "../../config/environment.js";

import { sendPasswordResetEmail } from "../../services/email.service.js";

import {
  REFRESH_REUSE_GRACE_MS,
  REFRESH_TOKEN_TTL_MS,
} from "../../constants/security.js";

import {
  badRequest,
  conflict,
  notFound,
  sessionReplaced,
  unauthorized,
} from "../../shared/utils/AppError.js";

import {
  isSessionExpired,
  isSessionRevoked,
  parseDurationToMs,
} from "../../shared/utils/session.js";

import {
  generateRefreshToken,
  parseRefreshToken,
  refreshTokenHashMatches,
} from "../../shared/utils/refreshTokens.js";

import { signAccessToken } from "../../shared/utils/tokens.js";

import { logSecurityEvent } from "../../shared/utils/securityLogger.js";

import type { IUser } from "./auth.model.js";

import {
  createUser,
  findUserByEmail,
  findUserById,
  findUserByResetTokenHash,
  saveUser,
} from "./auth.repository.js";

import {
  createSession,
  findActiveSessionsByUser,
  findSessionById,
  revokeAllSessions,
  revokeOtherSessions,
  revokeSessionForUser,
  updateSessionRefresh,
} from "./session.repository.js";

import { sessionCache } from "./session.cache.js";

import type {
  AuthenticatedUser,
  AuthResult,
  PublicUser,
  SessionSummary,
} from "./auth.types.js";

// --------------------------------------------------
// CONSTANTS
// --------------------------------------------------

const DUMMY_PASSWORD_HASH =
  "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy";

// --------------------------------------------------
// USER SERIALIZATION
// --------------------------------------------------

const toPublicUser = (user: IUser): PublicUser => ({
  id: String(user._id),
  ...(user.name ? { name: user.name } : {}),
  email: user.email,
  role: user.role ?? "user",
});

// --------------------------------------------------
// SESSION MANAGEMENT
// --------------------------------------------------

/** Deadline of a session. Refreshing rotates the token but never extends it. */
const sessionExpiry = (): Date => {
  const configuredExpiry = parseDurationToMs(getRefreshTokenExpiresIn());

  const ttl = configuredExpiry ?? REFRESH_TOKEN_TTL_MS;

  return new Date(Date.now() + ttl);
};

const startSession = async (
  user: IUser,
  context: { userAgent?: string | null } = {},
): Promise<AuthResult> => {
  const { token, sessionId } = signAccessToken(String(user._id), user.email);
  const { token: refreshToken, hash } = generateRefreshToken(sessionId);

  // Persist the session before returning the tokens.
  await createSession({
    id: sessionId,
    userId: String(user._id),
    expiresAt: sessionExpiry(),
    refreshTokenHash: hash,
    userAgent: context.userAgent ?? null,
  });

  if (!allowConcurrentSessions()) {
    // Newest login wins: every older device's session ends immediately.
    await revokeOtherSessions(String(user._id), sessionId);
    sessionCache.invalidateUser(String(user._id));
  }

  user.lastLoginAt = new Date();

  await saveUser(user);

  return {
    token,
    refreshToken,
    user: toPublicUser(user),
  };
};

// --------------------------------------------------
// ERROR HANDLING
// --------------------------------------------------

const isDuplicateKeyError = (err: unknown): boolean => {
  if (typeof err !== "object" || err === null) {
    return false;
  }

  return "code" in err && (err.code === 11000 || err.code === 11001);
};

// --------------------------------------------------
// USER REGISTRATION
// --------------------------------------------------

export const signup = async (input: {
  name?: string;
  email: string;
  password: string;
  userAgent?: string | null;
}): Promise<AuthResult> => {
  const email = input.email.trim().toLowerCase();

  // Check for an existing account.
  const existingUser = await findUserByEmail(email);

  if (existingUser) {
    throw conflict("Email already registered");
  }

  // Hash password before database storage.
  const passwordHash = await bcrypt.hash(input.password, getBcryptRounds());

  let user: IUser;

  try {
    user = await createUser({
      ...(input.name?.trim() ? { name: input.name.trim() } : {}),
      email,
      passwordHash,
    });
  } catch (err) {
    if (isDuplicateKeyError(err)) {
      throw conflict("Email already registered");
    }

    throw err;
  }

  return startSession(user, { userAgent: input.userAgent });
};

// --------------------------------------------------
// USER LOGIN
// --------------------------------------------------

export const login = async (input: {
  email: string;
  password: string;
  userAgent?: string | null;
}): Promise<AuthResult> => {
  const email = input.email.trim().toLowerCase();

  const user = await findUserByEmail(email, true);

  // Perform password comparison even when user does not exist.
  const passwordHash = user?.passwordHash ?? DUMMY_PASSWORD_HASH;

  const validPassword = await bcrypt.compare(input.password, passwordHash);

  if (!user || !validPassword) {
    throw unauthorized("Invalid email or password");
  }

  return startSession(user, { userAgent: input.userAgent });
};

// --------------------------------------------------
// REFRESH TOKEN RENEWAL
// --------------------------------------------------

/**
 * Exchanges a refresh token for a new access/refresh token pair.
 *
 * The refresh token is rotated on every use. Replaying a superseded token
 * after the short grace window revokes the whole session, so a stolen token
 * cannot keep a foothold — the legitimate client must sign in again.
 */
export const refreshSession = async (input: {
  refreshToken: string;
}): Promise<AuthResult> => {
  const parts = parseRefreshToken(input.refreshToken);
  if (!parts) {
    throw unauthorized("Invalid or expired session");
  }

  const session = await findSessionById(parts.sessionId);
  const now = new Date();

  if (!session || isSessionRevoked(session) || isSessionExpired(session, now)) {
    throw unauthorized("Invalid or expired session");
  }

  const matchesCurrent = refreshTokenHashMatches(
    parts.secret,
    session.refreshTokenHash,
  );
  const matchesPrevious = refreshTokenHashMatches(
    parts.secret,
    session.previousRefreshTokenHash,
  );
  const withinGraceWindow =
    session.refreshedAt != null &&
    now.getTime() - session.refreshedAt.getTime() <= REFRESH_REUSE_GRACE_MS;

  if (!matchesCurrent && !(matchesPrevious && withinGraceWindow)) {
    if (matchesPrevious) {
      // A once-valid token replayed long after rotation: assume theft.
      await revokeSessionForUser(String(session._id), session.userId);
      sessionCache.invalidate(session.userId, String(session._id));
      logSecurityEvent("refresh_token_reuse", {
        userId: session.userId,
        sessionId: String(session._id),
      });
    }
    throw unauthorized("Invalid or expired session");
  }

  const user = await findUserById(session.userId);
  if (!user) {
    // The account no longer exists; the session must not outlive it.
    await revokeSessionForUser(String(session._id), session.userId);
    sessionCache.invalidate(session.userId, String(session._id));
    throw unauthorized("Invalid or expired session");
  }

  const next = generateRefreshToken(String(session._id));
  await updateSessionRefresh(String(session._id), {
    refreshTokenHash: next.hash,
    previousRefreshTokenHash: session.refreshTokenHash ?? null,
    refreshedAt: now,
    lastUsedAt: now,
  });

  const { token } = signAccessToken(
    String(user._id),
    user.email,
    String(session._id),
  );

  return {
    token,
    refreshToken: next.token,
    user: toPublicUser(user),
  };
};

// --------------------------------------------------
// PASSWORD RESET
// --------------------------------------------------

const PASSWORD_RESET_TTL_MS = 30 * 60 * 1000;
const GENERIC_RESET_MESSAGE =
  "If an account exists for that email, a reset link has been sent.";

const hashResetToken = (rawToken: string): string =>
  createHash("sha256").update(rawToken).digest("hex");

/**
 * Handles a forgot-password request. Always returns the same message so the
 * endpoint cannot be used to enumerate registered email addresses.
 */
export const requestPasswordReset = async (input: {
  email: string;
}): Promise<{ message: string }> => {
  const email = input.email.trim().toLowerCase();
  const user = await findUserByEmail(email);
  if (!user) {
    return { message: GENERIC_RESET_MESSAGE };
  }

  const rawToken = randomBytes(32).toString("hex");
  user.passwordResetTokenHash = hashResetToken(rawToken);
  user.passwordResetExpiresAt = new Date(Date.now() + PASSWORD_RESET_TTL_MS);
  await saveUser(user);

  const resetUrl = `${getAppBaseUrl()}/reset-password?token=${encodeURIComponent(rawToken)}`;
  try {
    await sendPasswordResetEmail(email, resetUrl);
  } catch {
    // Do not leak whether the email was delivered — the reset link expires soon anyway.
  }

  return { message: GENERIC_RESET_MESSAGE };
};

/**
 * Applies a password reset. The link is single-use and expires quickly; all
 * active sessions are revoked so a stolen password cannot keep a session.
 */
export const resetPassword = async (input: {
  token: string;
  password: string;
}): Promise<{ message: string }> => {
  const tokenHash = hashResetToken(input.token.trim());
  const user = await findUserByResetTokenHash(tokenHash);

  const expired =
    !user?.passwordResetExpiresAt ||
    user.passwordResetExpiresAt.getTime() < Date.now();

  if (!user || expired) {
    throw badRequest("This reset link is invalid or has expired.");
  }

  const passwordHash = await bcrypt.hash(input.password, getBcryptRounds());

  user.passwordHash = passwordHash;
  user.passwordResetTokenHash = null;
  user.passwordResetExpiresAt = null;

  await saveUser(user);

  await revokeAllSessions(String(user._id));
  sessionCache.invalidateUser(String(user._id));

  return { message: "Password updated. Sign in with your new password." };
};

// --------------------------------------------------
// USER LOGOUT
// --------------------------------------------------

/** Ends the given session only; other devices stay signed in. */
export const logout = async (
  userId: string,
  sessionId: string,
): Promise<void> => {
  await revokeSessionForUser(sessionId, userId);
  sessionCache.invalidate(userId, sessionId);
};

// --------------------------------------------------
// CURRENT USER
// --------------------------------------------------

export const getCurrentUser = async (userId: string): Promise<PublicUser> => {
  const user = await findUserById(userId);

  if (!user) {
    throw unauthorized("Invalid or expired session");
  }

  return toPublicUser(user);
};

// --------------------------------------------------
// DEVICE (SESSION) MANAGEMENT
// --------------------------------------------------

export const listSessions = async (
  userId: string,
  currentSessionId: string,
): Promise<SessionSummary[]> => {
  const sessions = await findActiveSessionsByUser(userId);

  return sessions.map((session) => ({
    id: String(session._id),
    current: String(session._id) === currentSessionId,
    userAgent: session.userAgent ?? null,
    createdAt: session.createdAt,
    lastUsedAt: session.lastUsedAt,
    expiresAt: session.expiresAt,
  }));
};

/** Revokes one of the caller's sessions. Revoking the current one signs this
 *  device out. Idempotent; unknown or foreign sessions are a 404. */
export const revokeSession = async (
  userId: string,
  sessionId: string,
): Promise<void> => {
  const session = await findSessionById(sessionId);

  if (!session || session.userId !== userId) {
    throw notFound("Session not found");
  }

  if (!isSessionRevoked(session)) {
    await revokeSessionForUser(sessionId, userId);
    sessionCache.invalidate(userId, sessionId);
  }
};

// --------------------------------------------------
// SESSION AUTHENTICATION
// --------------------------------------------------

export const authenticateSession = async (
  userId: string,
  sessionId: string,
): Promise<AuthenticatedUser> => {
  const cached = sessionCache.get(userId, sessionId);
  if (cached) {
    return cached;
  }

  const user = await findUserById(userId);

  if (!user) {
    throw unauthorized("Invalid or expired session");
  }

  const session = await findSessionById(sessionId);

  if (!session || session.userId !== userId) {
    throw unauthorized("Invalid or expired session");
  }
  if (isSessionRevoked(session)) {
    throw sessionReplaced();
  }
  if (isSessionExpired(session)) {
    throw unauthorized("Invalid or expired session");
  }

  const authenticated: AuthenticatedUser = {
    ...toPublicUser(user),
    role: user.role ?? "user",
  };
  sessionCache.set(userId, sessionId, authenticated);

  return authenticated;
};
