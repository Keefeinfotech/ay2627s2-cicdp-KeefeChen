/**
 * File Name: member.repository.ts
 * Description: Data access layer for group membership operations.
 * Author: Keefe Chen
 */

import { ClientSession } from "mongoose";
import { Member, MemberStatus, type MemberRecord } from "./member.model.js";
import { GroupRole } from "../core/group.types.js";

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
   * Finds active group IDs for a user.
   */
  async findActiveGroupIdsByUser(userId: string): Promise<string[]> {
    const members = await Member.find({
      userId,
      status: MemberStatus.ACTIVE,
    })
      .select("groupId")
      .lean();

    return members.map((m) => m.groupId);
  }

  /**
   * Finds active membership for a group and user.
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
   * Lists all active members of a group.
   */
  async findByGroup(groupId: string): Promise<MemberRecord[]> {
    return Member.find({
      groupId,
      status: MemberStatus.ACTIVE,
    }).exec();
  }

  /**
   * Updates a member's role.
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