/**
 * File Name: member.model.ts
 * Description: Defines the MongoDB schema for group memberships.
 * Author: Keefe Chen
 */

import mongoose, { Schema, type InferSchemaType } from "mongoose";
import { GroupRole } from "../core/group.types.js";

export enum MemberStatus {
  ACTIVE = "ACTIVE",
  LEFT = "LEFT",
  REMOVED = "REMOVED",
}

const memberSchema = new Schema(
  {
    groupId: {
      type: String,
      required: true,
      trim: true,
      index: true,
    },
    userId: {
      type: String,
      required: true,
      trim: true,
      ref: "User",
      index: true,
    },
    role: {
      type: String,
      enum: Object.values(GroupRole),
      default: GroupRole.MEMBER,
      required: true,
    },
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

memberSchema.index({
  groupId: 1,
  status: 1,
  createdAt: -1,
});

memberSchema.index({
  userId: 1,
  status: 1,
});

export type MemberRecord = InferSchemaType<typeof memberSchema>;

export const Member =
  mongoose.models.Member ??
  mongoose.model("Member", memberSchema);