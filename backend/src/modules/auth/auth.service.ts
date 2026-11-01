import bcrypt from "bcryptjs";
import { allowConcurrentSessions, getBcryptRounds, getJwtExpiresIn } from "../../config/environment.js";
import { SESSION_TTL_MS } from "../../constants/security.js";
import { conflict, sessionReplaced, unauthorized } from "../../shared/utils/AppError.js";
import { isSessionActive, parseDurationToMs } from "../../shared/utils/session.js";
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

const DUMMY_PASSWORD_HASH =
  "$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy";

const toPublicUser = (user: IUser): PublicUser => ({
  id: String(user._id),
  ...(user.name ? { name: user.name } : {}),
  email: user.email,
});

const sessionExpiry = (): Date => {
  const configured = parseDurationToMs(getJwtExpiresIn());
  return new Date(Date.now() + (configured ?? SESSION_TTL_MS));
};

const startSession = async (user: IUser): Promise<AuthResult> => {
  const { token, sessionId } = signAccessToken(
    String(user._id),
    user.email
  );

  user.activeSessionId = sessionId;
  user.activeSessionExpiresAt = sessionExpiry();
  user.lastLoginAt = new Date();
  await saveUser(user);

  return { token, user: toPublicUser(user) };
};

const isDuplicateKeyError = (err: unknown): boolean => {
  if (typeof err !== "object" || err === null) return false;
  const candidate = err as { code?: number; name?: string };
  return (
    (candidate.code === 11000 || candidate.code === 11001) &&
    typeof candidate.name === "string" &&
    candidate.name.startsWith("Mongo")
  );
};

export const signup = async (input: {
  name?: string;
  email: string;
  password: string;
}): Promise<AuthResult> => {
  const existing = await findUserByEmail(input.email);
  if (existing) {
    throw conflict("Email already registered");
  }

  const passwordHash = await bcrypt.hash(input.password, getBcryptRounds());

  let user: IUser;
  try {
    user = await createUser({
      ...(input.name ? { name: input.name } : {}),
      email: input.email,
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

export const login = async (input: {
  email: string;
  password: string;
}): Promise<AuthResult> => {
  const user = await findUserByEmail(input.email, true);
  const passwordHash = user?.passwordHash ?? DUMMY_PASSWORD_HASH;
  const valid = await bcrypt.compare(input.password, passwordHash);

  if (!user || !valid) {
    throw unauthorized("Invalid email or password");
  }

  return startSession(user);
};

export const logout = async (userId: string): Promise<void> => {
  await clearActiveSession(userId);
};

export const getCurrentUser = async (userId: string): Promise<PublicUser> => {
  const user = await findUserById(userId);
  if (!user) {
    throw unauthorized("Invalid or expired session");
  }
  return toPublicUser(user);
};

export const authenticateSession = async (
  userId: string,
  sessionId: string
): Promise<AuthenticatedUser> => {
  const user = await findUserById(userId);
  if (!user) {
    throw unauthorized("Invalid or expired session");
  }

  if (!allowConcurrentSessions() && !isSessionActive(user, sessionId)) {
    throw sessionReplaced();
  }

  return { ...toPublicUser(user), role: user.role ?? "user" };
};
