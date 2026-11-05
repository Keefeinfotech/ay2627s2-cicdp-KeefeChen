/**
 * File Name: membership.ts
 * Description: Shared group authorisation helpers for group-scoped modules.
 * Author: Keefe Chen
 */

import { AppError } from "../../../shared/utils/AppError.js";
import { Member } from "../member/member.model.js";
import { GroupRole, GroupStatus } from "../core/group.types.js";
import { Group } from "../core/group.model.js";

export interface ActiveMembership {
  groupId: string;
  userId: string;
  role: GroupRole;
  status: string;
}

/**
 * Ensures the group exists, is not archived, and the user is an active member.
 */
export async function requireGroupMembership(
  groupId: string,
  userId: string,
): Promise<ActiveMembership> {
  if (!userId) {
    throw new AppError(
      401,
      "UNAUTHENTICATED",
      "Authentication is required.",
    );
  }

  if (!groupId || typeof groupId !== "string") {
    throw new AppError(400, "INVALID_GROUP_ID", "A group ID is required.");
  }

  const group = await Group.findOne({ groupId }).select("status").lean();

  if (!group) {
    throw new AppError(404, "GROUP_NOT_FOUND", "Group was not found.");
  }

  if (group.status === GroupStatus.ARCHIVED) {
    throw new AppError(
      409,
      "GROUP_ARCHIVED",
      "This group has been archived.",
    );
  }

  const membership = await Member.findOne({
    groupId,
    userId,
    status: "ACTIVE",
  }).lean();

  if (!membership) {
    throw new AppError(
      403,
      "GROUP_ACCESS_DENIED",
      "You are not an active member of this group.",
    );
  }

  return {
    groupId: membership.groupId,
    userId: membership.userId,
    role: membership.role as GroupRole,
    status: membership.status,
  };
}

/**
 * Requires an active membership whose role is in the allowed list.
 */
export async function requireGroupRole(
  groupId: string,
  userId: string,
  roles: readonly GroupRole[],
): Promise<ActiveMembership> {
  const membership = await requireGroupMembership(groupId, userId);

  if (!roles.includes(membership.role)) {
    throw new AppError(
      403,
      "GROUP_ROLE_FORBIDDEN",
      "Your group role does not allow this action.",
    );
  }

  return membership;
}

export const GROUP_MANAGER_ROLES: readonly GroupRole[] = [
  GroupRole.OWNER,
  GroupRole.ADMIN,
];
