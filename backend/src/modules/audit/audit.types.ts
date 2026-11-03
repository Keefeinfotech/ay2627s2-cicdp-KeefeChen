/**
 * File Name: audit.types.ts
 * Description: Domain types for the group activity trail.
 * Author: Keefe Chen
 */

export const AUDIT_ACTIONS = {
  GROUP_CREATED: "GROUP_CREATED",
  GROUP_UPDATED: "GROUP_UPDATED",
  GROUP_ARCHIVED: "GROUP_ARCHIVED",
  MEMBERS_ADDED: "MEMBERS_ADDED",
  INVITATION_SENT: "INVITATION_SENT",
  INVITATION_ACCEPTED: "INVITATION_ACCEPTED",
  ROADMAP_CREATED: "ROADMAP_CREATED",
  ROADMAP_UPDATED: "ROADMAP_UPDATED",
  ROADMAP_APPROVED: "ROADMAP_APPROVED",
  ROADMAP_DELETED: "ROADMAP_DELETED",
  RUBRIC_PARSED: "RUBRIC_PARSED",
  RUBRIC_DELETED: "RUBRIC_DELETED",
  SESSION_CREATED: "SESSION_CREATED",
  SESSION_UPDATED: "SESSION_UPDATED",
  SESSION_JOINED: "SESSION_JOINED",
  SESSION_LEFT: "SESSION_LEFT",
  SESSION_CANCELLED: "SESSION_CANCELLED",
  SESSION_COMPLETED: "SESSION_COMPLETED",
} as const;

export type AuditAction =
  (typeof AUDIT_ACTIONS)[keyof typeof AUDIT_ACTIONS];

export interface RecordAuditInput {
  groupId: string;
  actorId: string;
  action: AuditAction | string;
  targetType?: string | null;
  targetId?: string | null;
  metadata?: Record<string, unknown> | null;
}

export interface ListAuditQuery {
  page?: number;
  limit?: number;
  action?: string;
}

export interface AuditPagination {
  page: number;
  limit: number;
  totalItems: number;
  totalPages: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
}

export interface AuditListResult<T> {
  items: T[];
  pagination: AuditPagination;
}
