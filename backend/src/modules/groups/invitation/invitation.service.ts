/**
 * File Name: invitation.service.ts
 * Description: Handles business logic for group invitations.
 * Author: Keefe Chen
 */

import { createHash, randomBytes } from "node:crypto";

import mongoose from "mongoose";

import { getAppBaseUrl } from "../../../config/environment.js";
import logger from "../../../config/logger.js";
import { sendGroupInvitationEmail } from "../../../services/email.service.js";
import { GroupRepository } from "../core/group.repository.js";
import { MemberRepository } from "../member/member.repository.js";
import { MemberStatus } from "../member/member.model.js";
import { userRepository } from "../../users/user.repository.js";

import { GroupRole } from "../core/group.types.js";

import { InvitationRepository } from "./invitation.repository.js";

import {
  InvitationStatus,
  type CreateInvitationInput,
} from "./invitation.types.js";

const groupRepository = new GroupRepository();
const memberRepository = new MemberRepository();
const invitationRepository = new InvitationRepository();

const INVITATION_EXPIRY_DAYS = 7;

export class InvitationService {
  /**
   * Creates an invitation for a user to join a group.
   */
  async create(
    userId: string,
    input: CreateInvitationInput,
  ) {
    // 1. Check that the group exists and is active.
    const group = await groupRepository.findById(input.groupId);

    if (!group) {
      throw new Error("Group not found.");
    }

    // 2. Check the inviter's active group membership.
    const inviter =
      await memberRepository.findActiveByGroupAndUser(
        input.groupId,
        userId,
      );

    // 3. Only owners and administrators can invite members.
    const canInvite =
      inviter?.role === GroupRole.OWNER ||
      inviter?.role === GroupRole.ADMIN;

    if (!canInvite) {
      throw new Error(
        "You do not have permission to invite members.",
      );
    }

    // 4. Normalize the recipient's email.
    const email = input.email.trim().toLowerCase();

    // 5. Prevent duplicate pending invitations.
    const existingInvitation =
      await invitationRepository.findPendingByEmail(
        input.groupId,
        email,
      );

    if (existingInvitation) {
      throw new Error(
        "A pending invitation already exists for this email.",
      );
    }

    // 6. Generate a secure random invitation token.
    const rawToken = randomBytes(32).toString("hex");

    // Store only the hash in the database.
    const tokenHash = createHash("sha256")
      .update(rawToken)
      .digest("hex");

    // 7. Set invitation expiry.
    const expiresAt = new Date(
      Date.now() +
        INVITATION_EXPIRY_DAYS * 24 * 60 * 60 * 1000,
    );

    // 8. Create the invitation record.
    const invitation = await invitationRepository.create({
      ...input,
      email,
      invitedBy: userId,
      tokenHash,
      expiresAt,
    });

    // 9. Deliver the token. Email is preferred; when SMTP is unavailable the
    //    raw token is returned for manual delivery inside the same response.
    const acceptUrl =
      `${getAppBaseUrl()}/invitations/accept?token=${encodeURIComponent(rawToken)}`;
    let delivery: "email" | "manual" = "manual";
    try {
      const delivered = await sendGroupInvitationEmail({
        recipient: email,
        acceptUrl,
        groupName: group.name,
        role: input.role,
      });
      if (delivered) delivery = "email";
    } catch (error) {
      logger.warn("group.invitation.email_failed", {
        invitationId: invitation.invitationId,
        groupId: input.groupId,
        message: error instanceof Error ? error.message : String(error),
      });
    }

    return {
      invitation: {
        invitationId: invitation.invitationId,
        groupId: invitation.groupId,
        email: invitation.email,
        role: invitation.role,
        status: invitation.status,
        invitedBy: invitation.invitedBy,
        expiresAt: invitation.expiresAt,
        createdAt: invitation.createdAt,
      },
      delivery,
      ...(delivery === "manual" ? { invitationToken: rawToken } : {}),
    };
  }

  /**
   * Retrieves an invitation.
   */
  async get(
    invitationId: string,
    userId: string,
  ) {
    // 1. Find the invitation.
    const invitation =
      await invitationRepository.findById(invitationId);

    if (!invitation) {
      throw new Error("Invitation not found.");
    }

    // 2. Check the user's membership in the group.
    const member =
      await memberRepository.findActiveByGroupAndUser(
        invitation.groupId,
        userId,
      );

    // 3. Check whether the user is allowed to view it.
    const canView =
      invitation.invitedBy === userId ||
      member?.role === GroupRole.OWNER ||
      member?.role === GroupRole.ADMIN;

    if (!canView) {
      throw new Error(
        "You do not have permission to view this invitation.",
      );
    }

    return invitation;
  }

  /**
   * Accepts an invitation using its token.
   */
  async accept(
    userId: string,
    input: { token: string },
  ) {
    // 1. Hash the supplied token.
    const tokenHash = createHash("sha256")
      .update(input.token)
      .digest("hex");

    // 2. Find the pending, non-expired invitation.
    const invitation =
      await invitationRepository.findByTokenHash(tokenHash);

    if (!invitation) {
      throw new Error(
        "Invalid, expired or unavailable invitation.",
      );
    }

    // 3. Confirm that the invitation is pending.
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new Error(
        "This invitation is no longer available.",
      );
    }

    // 4. Confirm that the invitation has not expired.
    if (invitation.expiresAt.getTime() <= Date.now()) {
      throw new Error("This invitation has expired.");
    }

    // 5. Bind the token to the signed-in account. An invitation token is
    //    delivered to one email address, so accepting it with a different
    //    account must not grant membership.
    const user = await userRepository.findById(userId);

    if (!user) {
      throw new Error("Your account could not be found.");
    }

    if (
      user.email.trim().toLowerCase() !==
      invitation.email.trim().toLowerCase()
    ) {
      throw new Error(
        "This invitation was sent to a different email address.",
      );
    }

    // 6. Activate the membership and accept the invitation atomically. If
    //    either write fails, neither the roster nor the invitation changes.
    const session = await mongoose.startSession();

    try {
      let acceptedInvitation:
        | Awaited<
            ReturnType<typeof invitationRepository.accept>
          >
        | null = null;

      await session.withTransaction(async () => {
        await memberRepository.activate(
          {
            groupId: invitation.groupId,
            userId,
            role: invitation.role,
            status: MemberStatus.ACTIVE,
          },
          session,
        );

        acceptedInvitation =
          await invitationRepository.accept(
            invitation.invitationId,
            session,
          );
      });

      if (!acceptedInvitation) {
        throw new Error(
          "The invitation has already been accepted, expired or revoked.",
        );
      }

      return acceptedInvitation;
    } finally {
      await session.endSession();
    }
  }

  /**
   * Cancels an invitation.
   */
  async cancel(
    invitationId: string,
    userId: string,
  ) {
    // 1. Find the invitation.
    const invitation =
      await invitationRepository.findById(invitationId);

    if (!invitation) {
      throw new Error("Invitation not found.");
    }

    // 2. Check the user's group membership.
    const member =
      await memberRepository.findActiveByGroupAndUser(
        invitation.groupId,
        userId,
      );

    // 3. Check cancellation permissions.
    const canCancel =
      invitation.invitedBy === userId ||
      member?.role === GroupRole.OWNER ||
      member?.role === GroupRole.ADMIN;

    if (!canCancel) {
      throw new Error(
        "You do not have permission to cancel this invitation.",
      );
    }

    // 4. Only pending invitations can be cancelled.
    if (invitation.status !== InvitationStatus.PENDING) {
      throw new Error(
        "Only pending invitations can be cancelled.",
      );
    }

    // 5. Revoke the invitation.
    const revokedInvitation =
      await invitationRepository.revoke(
        invitationId,
        invitation.groupId,
      );

    if (!revokedInvitation) {
      throw new Error(
        "The invitation could not be cancelled.",
      );
    }

    return revokedInvitation;
  }
}