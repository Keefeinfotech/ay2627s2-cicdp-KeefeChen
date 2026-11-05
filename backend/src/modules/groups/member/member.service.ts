/**
 * File Name: member.service.ts
 * Description: Lists group members with their public profile information.
 */

import { MemberRepository } from "./member.repository.js";
import { GroupRepository } from "../core/group.repository.js";
import { userRepository } from "../../users/user.repository.js";

const memberRepository = new MemberRepository();
const groupRepository = new GroupRepository();

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

export class MemberService {
  /**
   * Lists active members of a group.
   *
   * Only active members of the group can read its roster, so an outsider
   * cannot enumerate the people in a private group.
   */
  async list(
    groupId: string,
    userId: string,
    options: { page: number; limit: number },
  ) {
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

    if (!membership) {
      throw createError(
        "You do not have permission to view this group.",
        403,
        "GROUP_ACCESS_DENIED",
      );
    }

    const { items, totalItems } =
      await memberRepository.listActiveByGroup(
        groupId,
        options.page,
        options.limit,
      );

    const users = await userRepository.findByIds(
      items.map((member) => member.userId),
    );
    const usersById = new Map(
      users.map((user) => [user._id, user]),
    );

    return {
      items: items.map((member) => {
        const user = usersById.get(member.userId);

        return {
          userId: member.userId,
          role: member.role,
          status: member.status,
          name: user?.name ?? null,
          email: user?.email ?? null,
          joinedAt: member.createdAt,
        };
      }),
      pagination: {
        page: options.page,
        limit: options.limit,
        totalItems,
        totalPages: Math.ceil(totalItems / options.limit),
        hasNextPage:
          options.page * options.limit < totalItems,
        hasPreviousPage: options.page > 1,
      },
    };
  }
}
