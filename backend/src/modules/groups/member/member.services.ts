import { MemberRepository } from "./member.repository.js";
import { GroupRole, MemberStatus } from "../core/group.types.js";

type ServiceError = Error & {
  statusCode: number;
  code: string;
};

const createError = (
  message: string,
  statusCode: number,
  code: string
): ServiceError => {
  const error = new Error(message) as ServiceError;
  error.statusCode = statusCode;
  error.code = code;
  return error;
};

export class MemberService {
  constructor(private readonly memberRepository: MemberRepository) {}

  /**
   * Lists all members of a group if the requesting user is a member.
   */
  async listMembers(groupId: string, requestingUserId: string) {
    const membership =
      await this.memberRepository.findActiveByGroupAndUser(
        groupId,
        requestingUserId
      );

    if (!membership) {
      throw createError(
        "You do not have access to view members of this group.",
        403,
        "MEMBER_ACCESS_DENIED"
      );
    }

    return this.memberRepository.findByGroup(groupId);
  }

  /**
   * Adds a user as a member to a group.
   */
  async addMember(
    groupId: string,
    requestingUserId: string,
    targetUserId: string,
    role: GroupRole = GroupRole.MEMBER
  ) {
    const requester = await this.memberRepository.findActiveByGroupAndUser(
      groupId,
      requestingUserId
    );

    if (!requester || (requester.role !== GroupRole.OWNER && requester.role !== GroupRole.ADMIN)) {
      throw createError(
        "Only group owners and admins can add members.",
        403,
        "MEMBER_ADD_FORBIDDEN"
      );
    }

    const existingMember = await this.memberRepository.findActiveByGroupAndUser(
      groupId,
      targetUserId
    );

    if (existingMember) {
      throw createError(
        "User is already a member of this group.",
        409,
        "MEMBER_ALREADY_EXISTS"
      );
    }

    return this.memberRepository.create({
      groupId,
      userId: targetUserId,
      role,
      status: MemberStatus.ACTIVE as MemberStatus | undefined,
    });
  }

  /**
   * Updates a member's role in a group.
   */
  async updateMemberRole(
    groupId: string,
    requestingUserId: string,
    targetUserId: string,
    newRole: GroupRole
  ) {
    const requester = await this.memberRepository.findActiveByGroupAndUser(
      groupId,
      requestingUserId
    );

    if (!requester || requester.role !== GroupRole.OWNER) {
      throw createError(
        "Only the group owner can update member roles.",
        403,
        "MEMBER_ROLE_UPDATE_FORBIDDEN"
      );
    }

    const updated = await this.memberRepository.updateRole(
      groupId,
      targetUserId,
      newRole
    );

    if (!updated) {
      throw createError("Member not found.", 404, "MEMBER_NOT_FOUND");
    }

    return updated;
  }

  /**
   * Removes a member from a group.
   */
  async removeMember(
    groupId: string,
    requestingUserId: string,
    targetUserId: string
  ) {
    const requester = await this.memberRepository.findActiveByGroupAndUser(
      groupId,
      requestingUserId
    );

    const isSelfRemoval = requestingUserId === targetUserId;

    if (!isSelfRemoval) {
      if (!requester || (requester.role !== GroupRole.OWNER && requester.role !== GroupRole.ADMIN)) {
        throw createError(
          "Only owners or admins can remove other members.",
          403,
          "MEMBER_REMOVE_FORBIDDEN"
        );
      }
    }

    const removed = await this.memberRepository.remove(groupId, targetUserId);

    if (!removed) {
      throw createError("Member not found.", 404, "MEMBER_NOT_FOUND");
    }

    return removed;
  }
}