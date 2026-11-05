
/**
 * File Name: group.model.ts
 * Description: Defines the Group MongoDB schema and model.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, {
  Schema,
  type HydratedDocument,
  type Model,
} from "mongoose";

import {
  GroupStatus,
  GroupVisibility,
} from "./group.types.js";

/**
 * Represents the persisted Group fields.
 */
export interface GroupRecord {
  groupId: string;
  name: string;
  description?: string;
  visibility: GroupVisibility;
  status: GroupStatus;
  ownerId: string;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Represents a hydrated Mongoose Group document.
 */
export type GroupDocument = HydratedDocument<GroupRecord>;

const groupSchema = new Schema<GroupRecord>(
  {
    groupId: {
      type: String,
      default: () => randomUUID(),
      unique: true,
      immutable: true,
    },

    name: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 80,
    },

    description: {
      type: String,
      trim: true,
      maxlength: 500,
      default: undefined,
    },

    visibility: {
      type: String,
      enum: Object.values(GroupVisibility),
      default: GroupVisibility.PRIVATE,
      required: true,
    },

    status: {
      type: String,
      enum: Object.values(GroupStatus),
      default: GroupStatus.ACTIVE,
      required: true,
    },

    ownerId: {
      type: String,
      required: true,
      immutable: true,
      ref: "User",
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  }
);

/**
 * Supports retrieving a user's groups by status
 * and sorting them by creation date.
 */
groupSchema.index(
  {
    ownerId: 1,
    status: 1,
    createdAt: -1,
  },
  {
    name: "ix_groups_owner_status_created",
  }
);

/**
 * Supports text-based group discovery.
 */
groupSchema.index(
  {
    name: "text",
    description: "text",
  },
  {
    name: "ix_groups_text_search",
  }
);

/**
 * Register or reuse the Group model.
 */
export const Group: Model<GroupRecord> =
  (mongoose.models.Group as Model<GroupRecord> | undefined) ??
  mongoose.model<GroupRecord>("Group", groupSchema);

  /**
 * Represents the persisted Group Member fields.
 */
export interface GroupMemberRecord {
  groupId: string;
  userId: string;
  createdAt: Date;
  updatedAt: Date;
}

export type GroupMemberDocument = HydratedDocument<GroupMemberRecord>;

const groupMemberSchema = new Schema<GroupMemberRecord>(
  {
    groupId: {
      type: String,
      required: true,
      ref: "Group",
    },
    userId: {
      type: String,
      required: true,
      ref: "User",
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  }
);

// Prevent duplicate membership records
groupMemberSchema.index(
  { groupId: 1, userId: 1 },
  { unique: true, name: "ux_group_members_group_user" }
);

export const GroupMemberModel: Model<GroupMemberRecord> =
  (mongoose.models.GroupMember as Model<GroupMemberRecord> | undefined) ??
  mongoose.model<GroupMemberRecord>("GroupMember", groupMemberSchema);