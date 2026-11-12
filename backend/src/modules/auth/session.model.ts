import mongoose, { type Document, type Model, Schema } from "mongoose";

/**
 * One signed-in device.
 *
 * The document id doubles as the JWT id (jti), so an access token maps to its
 * session with a single lookup, and the refresh token bound to the same
 * session can be rotated without touching the user document.
 */
export interface IAuthSession extends Document<string> {
  _id: string;
  userId: string;
  /** sha256 of the current refresh token secret. Never returned by the API. */
  refreshTokenHash?: string | null;
  /** sha256 of the previous secret; a replay after the grace window is theft. */
  previousRefreshTokenHash?: string | null;
  /** When the token was last rotated — starts the reuse grace window. */
  refreshedAt?: Date | null;
  userAgent?: string | null;
  lastUsedAt: Date;
  expiresAt: Date;
  revokedAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const AuthSessionSchema = new Schema<IAuthSession>(
  {
    // String id (not ObjectId) because it is generated as a UUID for the JWT
    // jti and must accept arbitrary verified tokens without casting errors.
    _id: { type: String, required: true },
    userId: { type: String, required: true, index: true },
    refreshTokenHash: { type: String, default: null, select: false },
    previousRefreshTokenHash: { type: String, default: null, select: false },
    refreshedAt: { type: Date, default: null },
    userAgent: { type: String, default: null, maxlength: 255 },
    lastUsedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true },
    revokedAt: { type: Date, default: null },
  },
  { timestamps: true },
);

// Drop expired sessions automatically once their deadline passes.
AuthSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
// Device list per user, newest first.
AuthSessionSchema.index({ userId: 1, createdAt: -1 });

export const AuthSession =
  (mongoose.models.AuthSession as Model<IAuthSession> | undefined) ??
  mongoose.model<IAuthSession>("AuthSession", AuthSessionSchema);
