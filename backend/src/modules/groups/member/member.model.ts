/**
 * File Name: member.model.ts
 * Description: Defines the MongoDB schema for group memberships.
 * Author: Keefe Chen
 */

import mongoose, {
  Schema,
  type InferSchemaType,
} from "mongoose";

import { GroupRole } from "../group/group.types.js";

export enum MemberStatus {
  ACTIVE = "ACTIVE",
  LEFT = "LEFT",
  REMOVED = "REMOVED",
}

const memberSchema = new Schema(
  {
    /**
     * Public UUID of the group.
     * This references Group.groupId, not MongoDB's _id.
     */
    groupId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },

    /**
     * UUID of the user who belongs to the group.
     */
    userId: {
      type: String,
      required: true,
      trim: true,
      ref: "User",
      index: true,
    },

    /**
     * Role determines the user's permissions within the group.
     */
    role: {
      type: String,
      enum: Object.values(GroupRole),
      default: GroupRole.MEMBER,
      required: true,
    },

    /**
     * Tracks the membership lifecycle.
     */
    status: {
      type: String,
      enum: Object.values(MemberStatus),
      default: MemberStatus.ACTIVE,
      required: true,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",
  },
);

/**
 * Prevents duplicate membership records for the same user and group.
 *
 * Existing membership records should be reactivated when a user rejoins.
 */
memberSchema.index(
  {
    groupId: 1,
    userId: 1,
  },
  {
    unique: true,
    name: "unique_group_user_membership",
  },
);

/**
 * Supports retrieving active members within a group.
 */
memberSchema.index({
  groupId: 1,
  status: 1,
  createdAt: -1,
});

/**
 * Supports retrieving a user's active group memberships.
 */
memberSchema.index({
  userId: 1,
  status: 1,
});

export type MemberRecord = InferSchemaType<typeof memberSchema>;

export const Member =
  mongoose.models.Member ??
  mongoose.model("Member", memberSchema);