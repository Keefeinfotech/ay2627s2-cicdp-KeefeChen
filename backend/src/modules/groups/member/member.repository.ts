/**
 * File Name: member.repository.ts
 * Description: Data access layer for group membership operations.
 * Author: Keefe Chen
 */

import mongoose, { ClientSession } from "mongoose";
import { Member, MemberStatus, type MemberRecord } from "./member.model.js";
import { GroupRole } from "../core/group.types.js";
import { CreateMemberInput } from "./member.types.js";

export class MemberRepository {
  /**
   * Creates a new member record.
   */
  async create(
    input: {
      groupId: string;
      userId: string;
      role: GroupRole;
      status?: MemberStatus;
    },
    session?: ClientSession,
  ): Promise<MemberRecord> {
    const docs = await Member.create([input], { session });
    return docs[0];
  }

  /**
   * Creates or reactivates a membership.
   *
   * The unique (groupId, userId) index means a user who previously left must
   * reuse the existing record instead of inserting a duplicate.
   */
  async activate(
    input: CreateMemberInput,
    session?: mongoose.ClientSession,
  ) {
    return Member.findOneAndUpdate(
      {
        groupId: input.groupId,
        userId: input.userId,
      },
      {
        $set: {
          role: input.role,
          status: input.status,
        },
      },
      {
        new: true,
        upsert: true,
        runValidators: true,
        setDefaultsOnInsert: true,
        session,
      },
    ).lean();
  }

  /**
   * Finds an active membership using group ID and user ID.
   */
  async findActiveByGroupAndUser(
    groupId: string,
    userId: string,
  ): Promise<MemberRecord | null> {
    return Member.findOne({
      groupId,
      userId,
      status: MemberStatus.ACTIVE,
    });
  }

  /**
   * Retrieves a user's active memberships for a set of groups.
   *
   * Used to attach the caller's role to group list results without one query
   * per group.
   */
  async findActiveByUserAndGroupIds(
    userId: string,
    groupIds: string[],
  ) {
    if (groupIds.length === 0) {
      return [];
    }

    return Member.find({
      userId,
      groupId: { $in: groupIds },
      status: "ACTIVE",
    }).lean();
  }

  /**
   * Retrieves the IDs of all groups the user actively belongs to.
   */
  async findActiveGroupIdsByUser(userId: string): Promise<string[]> {
    const memberships = await Member.find({
      userId,
      status: MemberStatus.ACTIVE,
    })
      .select("groupId")
      .lean()
      .exec();

    return memberships.map((membership) => membership.groupId);
  }

  /**
   * Retrieves all active group IDs belonging to a user.
   */
  async findByGroup(groupId: string): Promise<MemberRecord[]> {
    return Member.find({
      groupId,
      status: MemberStatus.ACTIVE,
    }).exec();
  }

  /**
   * Retrieves one page of active group members plus the total count.
   */
  async listActiveByGroup(
    groupId: string,
    page: number,
    limit: number,
  ) {
    const filter = {
      groupId,
      status: "ACTIVE" as const,
    };

    const [items, totalItems] = await Promise.all([
      Member.find(filter)
        .sort({ createdAt: 1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),

      Member.countDocuments(filter),
    ]);

    return { items, totalItems };
  }

  /**
   * Updates a member's role within a group.
   */
  async updateRole(
    groupId: string,
    userId: string,
    role: GroupRole,
  ): Promise<MemberRecord | null> {
    return Member.findOneAndUpdate(
      {
        groupId,
        userId,
        status: MemberStatus.ACTIVE,
      },
      { role },
      { new: true },
    );
  }

  /**
   * Soft-deletes a member by marking status as LEFT.
   */
  async remove(
    groupId: string,
    userId: string,
  ): Promise<MemberRecord | null> {
    return Member.findOneAndUpdate(
      {
        groupId,
        userId,
        status: MemberStatus.ACTIVE,
      },
      { status: MemberStatus.LEFT },
      { new: true },
    );
  }
}