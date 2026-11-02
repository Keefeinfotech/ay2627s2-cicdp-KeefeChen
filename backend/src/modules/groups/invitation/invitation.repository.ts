/**
 * File Name: invitation.repository.ts
 * Description: Handles database operations for group invitations.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import { Invitation } from "./invitation.model.js";

import {
  InvitationStatus,
  type CreateInvitationInput,
} from "./invitation.types.js";

/**
 * Handles persistence operations for invitations.
 */
export class InvitationRepository {
  /**
   * Creates a new invitation.
   */
  async create(
    input: CreateInvitationInput & {
      tokenHash: string;
      expiresAt: Date;
    },
    session?: mongoose.ClientSession,
  ) {
    const [invitation] = await Invitation.create(
      [{ ...input }],
      { session },
    );

    return invitation;
  }

  /**
   * Finds an invitation by its application ID.
   */
  async findById(invitationId: string) {
    return Invitation.findOne({ invitationId })
      .select("-tokenHash")
      .lean();
  }

  /**
   * Finds an invitation using its hashed token.
   */
  async findByTokenHash(tokenHash: string) {
    return Invitation.findOne({
      tokenHash,
      status: InvitationStatus.PENDING,
      expiresAt: { $gt: new Date() },
    }).select("+tokenHash");
  }

  /**
   * Finds an existing pending invitation
   * for the same group and email address.
   */
  async findPendingByEmail(
    groupId: string,
    email: string,
  ) {
    return Invitation.findOne({
      groupId,
      email: email.toLowerCase().trim(),
      status: InvitationStatus.PENDING,
      expiresAt: { $gt: new Date() },
    })
      .select("-tokenHash")
      .lean();
  }

  /**
   * Accepts a pending invitation.
   */
  async accept(
    invitationId: string,
    session?: mongoose.ClientSession,
  ) {
    return Invitation.findOneAndUpdate(
      {
        invitationId,
        status: InvitationStatus.PENDING,
        expiresAt: { $gt: new Date() },
      },
      {
        $set: {
          status: InvitationStatus.ACCEPTED,
          acceptedAt: new Date(),
        },
      },
      {
        new: true,
        runValidators: true,
        session,
      },
    )
      .select("-tokenHash")
      .lean();
  }

  /**
   * Declines a pending invitation.
   */
  async decline(invitationId: string) {
    return Invitation.findOneAndUpdate(
      {
        invitationId,
        status: InvitationStatus.PENDING,
        expiresAt: { $gt: new Date() },
      },
      {
        $set: {
          status: InvitationStatus.DECLINED,
        },
      },
      {
        new: true,
        runValidators: true,
      },
    )
      .select("-tokenHash")
      .lean();
  }

  /**
   * Revokes an invitation belonging to a group.
   */
  async revoke(
    invitationId: string,
    groupId: string,
  ) {
    return Invitation.findOneAndUpdate(
      {
        invitationId,
        groupId,
        status: InvitationStatus.PENDING,
      },
      {
        $set: {
          status: InvitationStatus.REVOKED,
        },
      },
      {
        new: true,
        runValidators: true,
      },
    )
      .select("-tokenHash")
      .lean();
  }

  /**
   * Alias used by the service when cancelling an invitation.
   */
  async cancel(invitationId: string) {
    const invitation = await this.findById(invitationId);

    if (!invitation) {
      return null;
    }

    return this.revoke(
      invitationId,
      invitation.groupId,
    );
  }

  /**
   * Lists invitations belonging to a group.
   */
  async listByGroup(
    groupId: string,
    page: number,
    limit: number,
    status?: InvitationStatus,
  ) {
    const filter: Record<string, unknown> = {
      groupId,
    };

    if (status) {
      filter.status = status;
    }

    const [items, total] = await Promise.all([
      Invitation.find(filter)
        .select("-tokenHash")
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),

      Invitation.countDocuments(filter),
    ]);

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * Marks expired pending invitations as EXPIRED.
   */
  async expirePending() {
    return Invitation.updateMany(
      {
        status: InvitationStatus.PENDING,
        expiresAt: { $lte: new Date() },
      },
      {
        $set: {
          status: InvitationStatus.EXPIRED,
        },
      },
    );
  }
}