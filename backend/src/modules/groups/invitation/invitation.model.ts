
/**
 * File Name: invitation.model.ts
 * Description: Defines the Invitation MongoDB schema and model.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";

import mongoose, {
  Schema,
  type HydratedDocument,
  type Model,
} from "mongoose";

import { GroupRole } from "../group/group.types.js";
import { InvitationStatus } from "./invitation.types.js";

/**
 * Represents the persisted invitation fields.
 */
export interface InvitationRecord {
  invitationId: string;
  groupId: string;
  email: string;
  role: GroupRole;
  status: InvitationStatus;
  invitedBy: string;
  tokenHash: string;
  expiresAt: Date;
  acceptedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Represents a hydrated Mongoose invitation document.
 */
export type InvitationDocument =
  HydratedDocument<InvitationRecord>;

const invitationSchema = new Schema<InvitationRecord>(
  {
    /**
     * UUID-based invitation identifier.
     */
    invitationId: {
      type: String,
      default: () => randomUUID(),
      unique: true,
      immutable: true,
    },

    /**
     * UUID of the group being joined.
     * This refers to Group.groupId, not MongoDB's _id.
     */
    groupId: {
      type: String,
      required: true,
      immutable: true,
      index: true,
    },

    /**
     * Email address of the invited user.
     */
    email: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
      maxlength: 254,
    },

    /**
     * Role assigned after the invitation is accepted.
     */
    role: {
      type: String,
      enum: [
        GroupRole.ADMIN,
        GroupRole.MEMBER,
      ],
      required: true,
      default: GroupRole.MEMBER,
    },

    /**
     * Current invitation status.
     */
    status: {
      type: String,
      enum: Object.values(InvitationStatus),
      required: true,
      default: InvitationStatus.PENDING,
    },

    /**
     * UUID of the user who sent the invitation.
     */
    invitedBy: {
      type: String,
      required: true,
      ref: "User",
    },

    /**
     * SHA-256 hash of the invitation token.
     * Never expose this field through API responses.
     */
    tokenHash: {
      type: String,
      required: true,
      select: false,
    },

    /**
     * Expiry date of the invitation.
     */
    expiresAt: {
      type: Date,
      required: true,
    },

    /**
     * Date when the invitation was accepted.
     */
    acceptedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  }
);

/**
 * Prevents duplicate pending invitations
 * for the same email address within a group.
 */
invitationSchema.index(
  {
    groupId: 1,
    email: 1,
  },
  {
    unique: true,
    partialFilterExpression: {
      status: InvitationStatus.PENDING,
    },
    name: "uq_pending_group_invitation_email",
  }
);

/**
 * Supports retrieving invitations belonging to a group.
 */
invitationSchema.index(
  {
    groupId: 1,
    status: 1,
    createdAt: -1,
  },
  {
    name: "ix_invitations_group_status_created",
  }
);

/**
 * Supports finding expired pending invitations.
 */
invitationSchema.index(
  {
    status: 1,
    expiresAt: 1,
  },
  {
    name: "ix_invitations_status_expiry",
  }
);

/**
 * Register or reuse the Invitation model.
 */
export const Invitation: Model<InvitationRecord> =
  (mongoose.models.Invitation as
    | Model<InvitationRecord>
    | undefined) ??
  mongoose.model<InvitationRecord>(
    "Invitation",
    invitationSchema
  );
