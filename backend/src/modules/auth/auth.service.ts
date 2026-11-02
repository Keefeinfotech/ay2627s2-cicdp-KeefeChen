
import bcrypt from "bcryptjs";

import {
  allowConcurrentSessions,
  getBcryptRounds,
  getJwtExpiresIn,
} from "../../config/environment.js";

import { SESSION_TTL_MS } from "../../constants/security.js";

import {
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
  const { token, sessionId } = signAccessToken(
    String(user._id),
    user.email
  );

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

  return (
    "code" in err &&
    (err.code === 11000 || err.code === 11001)
  );
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
  const passwordHash = await bcrypt.hash(
    input.password,
    getBcryptRounds()
  );

  let user: IUser;

  try {
    user = await createUser({
      ...(input.name?.trim()
        ? { name: input.name.trim() }
        : {}),
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
  const passwordHash =
    user?.passwordHash ?? DUMMY_PASSWORD_HASH;

  const validPassword = await bcrypt.compare(
    input.password,
    passwordHash
  );

  if (!user || !validPassword) {
    throw unauthorized("Invalid email or password");
  }

  return startSession(user);
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

export const getCurrentUser = async (
  userId: string
): Promise<PublicUser> => {
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
  sessionId: string
): Promise<AuthenticatedUser> => {
  const user = await findUserById(userId);

  if (!user) {
    throw unauthorized("Invalid or expired session");
  }

  if (
    !allowConcurrentSessions() &&
    !isSessionActive(user, sessionId)
  ) {
    throw sessionReplaced();
  }

  return {
    ...toPublicUser(user),
    role: user.role ?? "user",
  };
};
