/**
 * File Name: group.service.ts
 * Description: Handles business logic and access control for groups.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import { GroupRepository } from "./group.repository.js";
import { MemberRepository } from "../member/member.repository.js";

import {
  GroupRole,
  GroupStatus,
  GroupVisibility,
  type CreateGroupInput,
  type GroupListQuery,
  type UpdateGroupInput,
} from "./group.types.js";

const groupRepository = new GroupRepository();
const memberRepository = new MemberRepository();

type ServiceError = Error & {
  statusCode: number;
  code: string;
};

const createError = (
  message: string,
  statusCode: number,
  code: string,
): ServiceError => {
  const error = new Error(message) as ServiceError;
  error.statusCode = statusCode;
  error.code = code;
  return error;
};

export class GroupService {
  /**
   * Creates a group and registers its creator as the owner.
   * Both operations are performed in one transaction.
   */
  async create(userId: string, input: CreateGroupInput) {
    const session = await mongoose.startSession();

    try {
      let createdGroup: Awaited<
        ReturnType<typeof groupRepository.create>
      > | null = null;

      await session.withTransaction(async () => {
        createdGroup = await groupRepository.create(
          {
            ...input,
            name: input.name.trim(),
            description: input.description?.trim(),
            visibility: input.visibility ?? GroupVisibility.PRIVATE,
            ownerId: userId,
          },
          session,
        );

        await memberRepository.create(
          {
            groupId: createdGroup.groupId,
            userId,
            role: GroupRole.OWNER,
            status: "ACTIVE",
          },
          session,
        );
      });

      if (!createdGroup) {
        throw createError(
          "Unable to create group.",
          500,
          "GROUP_CREATE_FAILED",
        );
      }

      return createdGroup;
    } finally {
      await session.endSession();
    }
  }

  /**
   * Lists groups that the user is an active member of.
   */
  async list(userId: string, query: GroupListQuery) {
    const { page, limit, search } = query;

    const groupIds =
      await memberRepository.findActiveGroupIdsByUser(userId);

    if (groupIds.length === 0) {
      return {
        items: [],
        pagination: {
          page,
          limit,
          total: 0,
          totalPages: 0,
        },
      };
    }

    return groupRepository.list(groupIds, page, limit, search);
  }

  /**
   * Retrieves a group if the user is a member
   * or the group is publicly visible.
   */
  async get(groupId: string, userId: string) {
    const group = await groupRepository.findById(groupId);

    if (!group) {
      throw createError(
        "Group not found.",
        404,
        "GROUP_NOT_FOUND",
      );
    }

    const membership =
      await memberRepository.findActiveByGroupAndUser(
        groupId,
        userId,
      );

    const isPublic = group.visibility === GroupVisibility.PUBLIC;

    if (!membership && !isPublic) {
      throw createError(
        "You do not have permission to view this group.",
        403,
        "GROUP_ACCESS_DENIED",
      );
    }

    return group;
  }

  /**
   * Updates group details.
   * Only the group owner can update the group.
   */
  async update(
    groupId: string,
    userId: string,
    input: UpdateGroupInput,
  ) {
    const group = await groupRepository.findOwned(groupId, userId);

    if (!group) {
      throw createError(
        "Group not found or you are not the owner.",
        404,
        "GROUP_NOT_FOUND",
      );
    }

    const updateData: UpdateGroupInput = {};

    if (input.name !== undefined) {
      updateData.name = input.name.trim();
    }

    if (input.description !== undefined) {
      updateData.description = input.description.trim();
    }

    if (input.visibility !== undefined) {
      updateData.visibility = input.visibility;
    }

    const updatedGroup = await groupRepository.update(
      groupId,
      userId,
      updateData,
    );

    if (!updatedGroup) {
      throw createError(
        "Unable to update group.",
        500,
        "GROUP_UPDATE_FAILED",
      );
    }

    return updatedGroup;
  }

  /**
   * Archives a group.
   * Only the group owner can archive the group.
   */
  async archive(groupId: string, userId: string) {
    const archivedGroup = await groupRepository.archive(
      groupId,
      userId,
    );

    if (!archivedGroup) {
      throw createError(
        "Group not found or you are not the owner.",
        404,
        "GROUP_NOT_FOUND",
      );
    }

    return archivedGroup;
  }
}