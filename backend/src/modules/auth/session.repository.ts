import { AuthSession, type IAuthSession } from "./session.model.js";

const SESSION_ID_PROJECTION = "+refreshTokenHash +previousRefreshTokenHash";

const MAX_USER_AGENT_LENGTH = 255;

export interface CreateSessionInput {
  /** Session id; reused as the JWT id (jti) of every access token for it. */
  id: string;
  userId: string;
  expiresAt: Date;
  refreshTokenHash: string;
  userAgent?: string | null;
}

export const createSession = async (
  input: CreateSessionInput,
): Promise<IAuthSession> =>
  AuthSession.create({
    _id: input.id,
    userId: input.userId,
    expiresAt: input.expiresAt,
    refreshTokenHash: input.refreshTokenHash,
    userAgent: input.userAgent
      ? input.userAgent.slice(0, MAX_USER_AGENT_LENGTH)
      : null,
    lastUsedAt: new Date(),
  });

export const findSessionById = async (
  sessionId: string,
): Promise<IAuthSession | null> =>
  AuthSession.findById(sessionId).select(SESSION_ID_PROJECTION).exec();

export const findActiveSessionsByUser = async (
  userId: string,
): Promise<IAuthSession[]> =>
  AuthSession.find({ userId, revokedAt: null, expiresAt: { $gt: new Date() } })
    .sort({ createdAt: -1 })
    .exec();

/** Rotates the refresh token of a session (called after the presented secret
 *  has been verified against the stored hash). */
export const updateSessionRefresh = async (
  sessionId: string,
  fields: {
    refreshTokenHash: string;
    previousRefreshTokenHash: string | null;
    refreshedAt: Date;
    lastUsedAt: Date;
  },
): Promise<void> => {
  await AuthSession.updateOne({ _id: sessionId }, { $set: fields }).exec();
};

/** Revokes a session only if it still belongs to this user and is active. */
export const revokeSessionForUser = async (
  sessionId: string,
  userId: string,
): Promise<void> => {
  await AuthSession.updateOne(
    { _id: sessionId, userId, revokedAt: null },
    { $set: { revokedAt: new Date() } },
  ).exec();
};

/** Revokes every session except the given one (a newer login replaces older
 *  devices when ALLOW_CONCURRENT_SESSIONS is disabled). */
export const revokeOtherSessions = async (
  userId: string,
  keepSessionId: string,
): Promise<void> => {
  await AuthSession.updateMany(
    { userId, _id: { $ne: keepSessionId }, revokedAt: null },
    { $set: { revokedAt: new Date() } },
  ).exec();
};

/** Revokes every session for a user (password reset). */
export const revokeAllSessions = async (userId: string): Promise<void> => {
  await AuthSession.updateMany(
    { userId, revokedAt: null },
    { $set: { revokedAt: new Date() } },
  ).exec();
};
