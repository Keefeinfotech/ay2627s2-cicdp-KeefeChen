import mongoose, { type Document, Schema } from "mongoose";
import { USER_ROLES, type UserRole } from "../../constants/security.js";

export interface IUser extends Document {
  name?: string;
  email: string;
  passwordHash: string;
  role: UserRole;
  lastLoginAt?: Date | null;
  activeSessionId?: string | null;
  activeSessionExpiresAt?: Date | null;
  // MFA
  mfaEnabled?: boolean;
  mfaSecretEncrypted?: string | null;
  mfaPendingSecretEncrypted?: string | null;
  mfaPendingExpiresAt?: Date | null;
  mfaRecoveryCodeHashes?: string[];
  mfaLastUsedStep?: number | null;
  mfaEnabledAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    name: { type: String, trim: true, maxlength: 80 },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      maxlength: 254,
    },
    passwordHash: { type: String, required: true, select: false },
    role: {
      type: String,
      enum: USER_ROLES,
      default: "user",
      required: true,
    },
    lastLoginAt: { type: Date, default: null },
    activeSessionId: { type: String, default: null },
    activeSessionExpiresAt: { type: Date, default: null },

    // MFA
    mfaEnabled: { type: Boolean, default: false },
    mfaSecretEncrypted: { type: String, default: null, select: false },
    mfaPendingSecretEncrypted: { type: String, default: null, select: false },
    mfaPendingExpiresAt: { type: Date, default: null },
    mfaRecoveryCodeHashes: { type: [String], default: [], select: false },
    mfaLastUsedStep: { type: Number, default: null, select: false },
    mfaEnabledAt: { type: Date, default: null },
  },
  { timestamps: true }
);

export const User = mongoose.model<IUser>("User", UserSchema);
