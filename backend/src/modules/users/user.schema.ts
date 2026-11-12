/**
 * File Name: user.schema.ts
 * Description: The single user persistence schema shared by the auth and
 *              users modules. Both modules historically registered two
 *              near-identical `User` schemas against the same collection;
 *              whichever registered first per process then determined what
 *              Mongoose accepted, stripped, or rejected on writes. This file
 *              is the authority both use, so registration order no longer
 *              matters.
 *
 *              Field policy: union of the two prior schemas. `_id` is a String
 *              UUID (the users module's contract), which every other
 *              collection already uses. `name` stays optional because the
 *              auth sign-up path may omit it.
 *
 *              Authorization note: `status` gates administrative account
 *              state and is never settable from client input — only the
 *              admin service mutates it.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import { Schema } from "mongoose";

import {
  USER_ROLES,
  USER_STATUSES,
  type UserRole,
  type UserStatus,
} from "./user.types.js";

/**
 * Represents the raw persisted User data structure.
 *
 * passwordHash is optional in the TypeScript interface because Mongoose
 * excludes it from normal queries using select: false. Authentication queries
 * explicitly select this field.
 */
export interface UserRecord {
  _id: string;
  name?: string;
  email: string;
  passwordHash?: string;
  role: UserRole;
  status: UserStatus;

  // Email verification
  emailVerifiedAt: Date | null;
  emailVerificationTokenHash: string | null;
  emailVerificationExpiresAt: Date | null;

  // MFA
  mfaEnabled: boolean;
  mfaSecretEncrypted: string | null;
  mfaPendingSecretEncrypted: string | null;
  mfaPendingExpiresAt: Date | null;
  mfaRecoveryCodeHashes: string[];
  mfaLastUsedStep: number | null;
  mfaEnabledAt: Date | null;

  // Password reset
  passwordResetTokenHash: string | null;
  passwordResetExpiresAt: Date | null;

  lastLoginAt: Date | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export const userSchema = new Schema<UserRecord>(
  {
    /**
     * UUID-based user identifier. MUST stay a String: every other collection
     * references users by String UUID. Mixing ObjectId and String ids made
     * full-document saves cast-validate against the wrong type and fail.
     */
    _id: { type: String, default: () => randomUUID(), immutable: true },

    name: {
      type: String,
      trim: true,
      minlength: [2, "Name must contain at least 2 characters."],
      maxlength: [80, "Name cannot exceed 80 characters."],
    },

    email: {
      type: String,
      required: [true, "Email address is required."],
      lowercase: true,
      trim: true,
      maxlength: [254, "Email cannot exceed 254 characters."],
      match: [
        /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
        "Please provide a valid email address.",
      ],
    },

    passwordHash: {
      type: String,
      required: [true, "Password hash is required."],
      select: false,
    },

    role: {
      type: String,
      enum: USER_ROLES,
      default: "user",
      required: true,
      maxlength: 20,
    },

    status: {
      type: String,
      enum: USER_STATUSES,
      default: "pending",
      required: true,
      maxlength: 20,
    },

    lastLoginAt: { type: Date, default: null },

    emailVerifiedAt: { type: Date, default: null },
    emailVerificationTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    emailVerificationExpiresAt: { type: Date, default: null },

    // MFA settings
    mfaEnabled: { type: Boolean, default: false },
    mfaSecretEncrypted: { type: String, default: null, select: false },
    mfaPendingSecretEncrypted: { type: String, default: null, select: false },
    mfaPendingExpiresAt: { type: Date, default: null },
    mfaRecoveryCodeHashes: { type: [String], default: [], select: false },
    mfaLastUsedStep: { type: Number, default: null, select: false },
    mfaEnabledAt: { type: Date, default: null },

    // Password reset. Only the hash is stored. Never store the raw token.
    passwordResetTokenHash: { type: String, default: null, select: false },
    passwordResetExpiresAt: { type: Date, default: null },

    deletedAt: { type: Date, default: null },
  },
  {
    timestamps: true,
    versionKey: false,
    /**
     * Rejects fields that are not defined in the schema so a stray write
     * fails loudly instead of silently persisting nothing.
     */
    strict: "throw",
    toJSON: {
      transform: (_document, result: Record<string, unknown>) => {
        delete result.passwordHash;
        delete result.emailVerificationTokenHash;
        delete result.mfaSecretEncrypted;
        delete result.mfaPendingSecretEncrypted;
        delete result.mfaRecoveryCodeHashes;
        delete result.mfaLastUsedStep;
        delete result.passwordResetTokenHash;
        return result;
      },
    },
  },
);

// Enforces unique email addresses for active accounts only. Allows
// re-registration if an account was previously soft-deleted.
userSchema.index(
  { email: 1 },
  {
    unique: true,
    name: "uq_users_active_email",
    partialFilterExpression: { deletedAt: null },
  },
);

// Supports administrative filtering by account status and creation date.
userSchema.index(
  { status: 1, createdAt: -1 },
  { name: "ix_users_status_created_at" },
);

// Supports filtering and retrieving users by their role.
userSchema.index(
  { role: 1, createdAt: -1 },
  { name: "ix_users_role_created_at" },
);
userSchema.index(
  { emailVerificationTokenHash: 1 },
  { name: "ix_users_email_verification_token", sparse: true },
);
