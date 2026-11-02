/**
 * File Name: user.model.ts
 * Description: Defines the User entity, MongoDB schema,
 *              validation rules, indexes and document configuration.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type HydratedDocument, type Model } from "mongoose";

import {
  USER_ROLES,
  USER_STATUSES,
  type UserRole,
  type UserStatus,
} from "./user.types.js";

/**
 * Represents the raw persisted User data structure.
 *
 * passwordHash is optional in the TypeScript interface because
 * Mongoose excludes it from normal queries using select: false.
 * Authentication queries explicitly select this field.
 */
export interface UserRecord {
  _id: string;
  name: string;
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
  mfaRecoveryCodeHashes: string[];
  mfaLastUsedStep: number | null;

  lastLoginAt: Date | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Represents a hydrated Mongoose document instance for User.
 */
export type UserDocument = HydratedDocument<UserRecord>;

/**
 * Defines the MongoDB User schema.
 */
const userSchema = new Schema<UserRecord>(
  {
    /**
     * UUID-based user identifier.
     */
    _id: {
      type: String,
      default: () => String(randomUUID()),
      immutable: true,
    },

    /**
     * User's display name.
     */
    name: {
      type: String,
      required: [true, "Name is required."],
      trim: true,
      minlength: [2, "Name must contain at least 2 characters."],
      maxlength: [80, "Name cannot exceed 80 characters."],
    },

    /**
     * User's unique email address.
     */
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

    /**
     * Hashed password.
     *
     * Excluded from normal query results.
     * Authentication queries must explicitly select this field.
     */
    passwordHash: {
      type: String,
      required: [true, "Password hash is required."],
      select: false,
      maxlength: 255,
    },

    /**
     * User's assigned system role.
     */
    role: {
      type: String,
      required: true,
      enum: USER_ROLES,
      default: "user",
      maxlength: 20,
    },

    /**
     * Current account status.
     */
    status: {
      type: String,
      required: true,
      enum: USER_STATUSES,
      default: "pending",
      maxlength: 20,
    },

    /**
     * Timestamp when the user's email was verified.
     * Null means the email has not been verified.
     */
    emailVerifiedAt: {
      type: Date,
      default: null,
    },

    /**
     * Timestamp of the user's most recent successful login.
     */
    lastLoginAt: {
      type: Date,
      default: null,
    },

    /**
     * Timestamp when the user deactivated their account.
     *
     * Null means the account has not been deactivated.
     * Account records are retained instead of permanently deleted.
     */
    deletedAt: {
      type: Date,
      default: null,
    },
    // Email verification token hash. Never store the raw token.
emailVerificationTokenHash: {
  type: String,
  default: null,
  select: false,
},

emailVerificationExpiresAt: {
  type: Date,
  default: null,
},

// MFA settings
mfaEnabled: {
  type: Boolean,
  default: false,
},

// Active encrypted authenticator secret
mfaSecretEncrypted: {
  type: String,
  default: null,
  select: false,
},

// Temporary encrypted secret while MFA is being configured
mfaPendingSecretEncrypted: {
  type: String,
  default: null,
  select: false,
},

// Hashed one-time recovery codes
mfaRecoveryCodeHashes: {
  type: [String],
  default: [],
  select: false,
},

// Last accepted TOTP time step to prevent code reuse
mfaLastUsedStep: {
  type: Number,
  default: null,
}
  },
  {
    /**
     * Automatically maintains createdAt and updatedAt.
     */
    timestamps: true,

    /**
     * Disables Mongoose's default __v version field.
     */
    versionKey: false,

    /**
     * Rejects fields that are not defined in the schema.
     */
    strict: "throw",

    /**
     * Removes sensitive information during JSON serialization.
     */
    toJSON: {
  transform: (_document, result: Record<string, unknown>) => {
    delete result.passwordHash;
    delete result.emailVerificationTokenHash;
    delete result.mfaSecretEncrypted;
    delete result.mfaPendingSecretEncrypted;
    delete result.mfaRecoveryCodeHashes;
    delete result.mfaLastUsedStep;

    return result;
  },
},
  }
);

/**
 * DATABASE INDEXES
 *
 * Indexes improve the performance of frequently used queries.
 */

/**
 * Enforces unique email addresses for active accounts only.
 * Allows re-registration if an account was previously soft-deleted (deletedAt != null).
 */
userSchema.index(
  { email: 1 },
  {
    unique: true,
    name: "uq_users_active_email",
    partialFilterExpression: { deletedAt: null },
  }
);

/**
 * Supports administrative filtering by account status
 * and sorting by account creation date.
 */
userSchema.index(
  { status: 1, createdAt: -1 },
  {
    name: "ix_users_status_created_at",
  }
);

/**
 * Supports filtering and retrieving users by their role.
 */
userSchema.index(
  { role: 1, createdAt: -1 },
  {
    name: "ix_users_role_created_at",
  }
);

userSchema.index(
  { emailVerificationTokenHash: 1 },
  {
    name: "ix_users_email_verification_token",
    sparse: true,
  }
);

/**
 * MODEL REGISTRATION
 *
 * Reuses the existing User model during development
 * to prevent Mongoose model recompilation errors.
 */
export const User: Model<UserRecord> =
  (mongoose.models.User as Model<UserRecord> | undefined) ??
  mongoose.model<UserRecord>("User", userSchema);