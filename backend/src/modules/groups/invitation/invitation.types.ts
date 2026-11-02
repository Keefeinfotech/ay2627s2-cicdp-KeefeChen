
/**
 * File Name: invitation.types.ts
 * Description: Defines invitation statuses and input types.
 * Author: Keefe Chen
 */

import type { GroupRole } from "../group/group.types.js";

/**
 * Represents the current state of an invitation.
 */
export enum InvitationStatus {
  PENDING = "PENDING",
  ACCEPTED = "ACCEPTED",
  DECLINED = "DECLINED",
  REVOKED = "REVOKED",
  EXPIRED = "EXPIRED",
}

/**
 * Data required to create a group invitation.
 */
export interface CreateInvitationInput {
  groupId: string;
  email: string;
  role: GroupRole;
  invitedBy: string;
}

/**
 * Data required to accept an invitation.
 */
export interface AcceptInvitationInput {
  token: string;
}

/**
 * Query parameters for retrieving group invitations.
 */
export interface InvitationListQuery {
  page: number;
  limit: number;
  status?: InvitationStatus;
}

/**
 * Represents the public invitation information.
 */
export interface InvitationResponse {
  invitationId: string;
  groupId: string;
  email: string;
  role: GroupRole;
  status: InvitationStatus;
  expiresAt: Date;
  createdAt: Date;
}
