import { createHash, randomBytes } from "node:crypto";

import bcrypt from "bcryptjs";

import {
  allowConcurrentSessions,
  getAppBaseUrl,
  getBcryptRounds,
  getJwtExpiresIn,
} from "../../config/environment.js";

import { sendPasswordResetEmail } from "../../services/email.service.js";

import { SESSION_TTL_MS } from "../../constants/security.js";

import {
  badRequest,
  conflict,
  sessionReplaced,
  unauthorized,
} from "../../shared/utils/AppError.js";

import {
  isSessionActive,
  parseDurationToMs,
} from "../../shared/utils/session.js";

import { signAccessToken } from "../../shared/utils/tokens.js";

import type { IUser } from "./auth.model.js";

import {
  clearActiveSession,
  createUser,
  findUserByEmail,
  findUserById,
  findUserByResetTokenHash,
  saveUser,
} from "./auth.repository.js";

import type {
  AuthenticatedUser,
  AuthResult,
  PublicUser,
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
});

// --------------------------------------------------
// SESSION MANAGEMENT
// --------------------------------------------------

const sessionExpiry = (): Date => {
  const configuredExpiry = parseDurationToMs(getJwtExpiresIn());

  const ttl = configuredExpiry ?? SESSION_TTL_MS;

  return new Date(Date.now() + ttl);
};

const startSession = async (user: IUser): Promise<AuthResult> => {
  const { token, sessionId } = signAccessToken(String(user._id), user.email);

  // Persist the session before returning the token.
  user.activeSessionId = sessionId;
  user.activeSessionExpiresAt = sessionExpiry();
  user.lastLoginAt = new Date();

  await saveUser(user);

  return {
    token,
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

  return startSession(user);
};

// --------------------------------------------------
// USER LOGIN
// --------------------------------------------------

export const login = async (input: {
  email: string;
  password: string;
}): Promise<AuthResult> => {
  const email = input.email.trim().toLowerCase();

  const user = await findUserByEmail(email, true);

  // Perform password comparison even when user does not exist.
  const passwordHash = user?.passwordHash ?? DUMMY_PASSWORD_HASH;

  const validPassword = await bcrypt.compare(input.password, passwordHash);

  if (!user || !validPassword) {
    throw unauthorized("Invalid email or password");
  }

  return startSession(user);
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
  user.activeSessionId = null;
  user.activeSessionExpiresAt = null;

  await saveUser(user);

  return { message: "Password updated. Sign in with your new password." };
};

// --------------------------------------------------
// USER LOGOUT
// --------------------------------------------------

export const logout = async (userId: string): Promise<void> => {
  await clearActiveSession(userId);
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
// SESSION AUTHENTICATION
// --------------------------------------------------

export const authenticateSession = async (
  userId: string,
  sessionId: string,
): Promise<AuthenticatedUser> => {
  const user = await findUserById(userId);

  if (!user) {
    throw unauthorized("Invalid or expired session");
  }

  if (!allowConcurrentSessions() && !isSessionActive(user, sessionId)) {
    throw sessionReplaced();
  }

  return {
    ...toPublicUser(user),
    role: user.role ?? "user",
  };
};
