/**
 * File Name: member.repository.ts
 * Description: Handles database operations for group memberships.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import { Member } from "./member.model";

import type { GroupRole } from "../group/group.types.js";

interface CreateMemberInput {
  groupId: string;
  userId: string;
  role: GroupRole;
  status: "ACTIVE" | "LEFT" | "REMOVED";
}

export class MemberRepository {
  /**
   * Creates a new group membership.
   * An optional MongoDB session allows this operation
   * to participate in a transaction.
   */
  async create(
    input: CreateMemberInput,
    session?: mongoose.ClientSession,
  ) {
    const [member] = await Member.create(
      [input],
      { session },
    );

    return member;
  }

  /**
   * Finds an active membership using group ID and user ID.
   */
  async findActiveByGroupAndUser(
    groupId: string,
    userId: string,
  ) {
    return Member.findOne({
      groupId,
      userId,
      status: "ACTIVE",
    }).lean();
  }

  /**
   * Retrieves all active group IDs belonging to a user.
   */
  async findActiveGroupIdsByUser(userId: string): Promise<string[]> {
    const memberships = await Member.find({
      userId,
      status: "ACTIVE",
    })
      .select("groupId -_id")
      .lean();

    return memberships.map((membership) => membership.groupId);
  }

  /**
   * Retrieves all active members belonging to a group.
   */
  async findActiveByGroup(groupId: string) {
    return Member.find({
      groupId,
      status: "ACTIVE",
    }).lean();
  }

  /**
   * Updates a member's role within a group.
   */
  async updateRole(
    groupId: string,
    userId: string,
    role: GroupRole,
  ) {
    return Member.findOneAndUpdate(
      {
        groupId,
        userId,
        status: "ACTIVE",
      },
      {
        $set: { role },
      },
      {
        new: true,
        runValidators: true,
      },
    ).lean();
  }

  /**
   * Marks a member as having left a group.
   */
  async leaveGroup(groupId: string, userId: string) {
    return Member.findOneAndUpdate(
      {
        groupId,
        userId,
        status: "ACTIVE",
        role: { $ne: "OWNER" },
      },
      {
        $set: { status: "LEFT" },
      },
      {
        new: true,
        runValidators: true,
      },
    ).lean();
  }

  /**
   * Removes a member from a group.
   */
  async removeMember(groupId: string, userId: string) {
    return Member.findOneAndUpdate(
      {
        groupId,
        userId,
        status: "ACTIVE",
        role: { $ne: "OWNER" },
      },
      {
        $set: { status: "REMOVED" },
      },
      {
        new: true,
        runValidators: true,
      },
    ).lean();
  }

  /**
   * Counts active members in a group.
   */
  async countActiveMembers(groupId: string): Promise<number> {
    return Member.countDocuments({
      groupId,
      status: "ACTIVE",
    });
  }
}