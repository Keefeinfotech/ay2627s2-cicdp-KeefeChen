/**
 * File Name: member.types.ts
 * Description: Domain types for group memberships.
 * Author: Keefe Chen
 */

export type MemberStatusName = "ACTIVE" | "LEFT" | "REMOVED";

export interface MemberView {
  groupId: string;
  userId: string;
  role: string;
  status: MemberStatusName;
  createdAt: Date;
  updatedAt: Date;
}

export interface AddMembersInput {
  memberIds: string[];
  role?: string;
}

export interface UpdateMemberRoleInput {
  role: string;
}

export interface MembersPage {
  items: MemberView[];
  pagination: {
    page: number;
    limit: number;
    totalItems: number;
    totalPages: number;
    hasNextPage: boolean;
    hasPreviousPage: boolean;
  };
}
