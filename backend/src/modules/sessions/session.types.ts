/**
 * File Name: session.types.ts
 * Description: Domain types for group study sessions.
 * Author: Keefe Chen
 */

export const SESSION_STATUSES = [
  "scheduled",
  "completed",
  "cancelled",
] as const;

export type SessionStatus = (typeof SESSION_STATUSES)[number];

export interface SessionRecord {
  _id: string;
  groupId: string;
  title: string;
  description: string | null;
  startsAt: Date;
  endsAt: Date;
  location: string | null;
  maxAttendees: number | null;
  attendeeIds: string[];
  createdBy: string;
  status: SessionStatus;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateSessionInput {
  title: string;
  description?: string | null;
  startsAt: Date;
  endsAt: Date;
  location?: string | null;
  maxAttendees?: number | null;
}

export interface UpdateSessionInput {
  title?: string;
  description?: string | null;
  startsAt?: Date;
  endsAt?: Date;
  location?: string | null;
}

export interface ListSessionsQuery {
  status?: SessionStatus;
  from?: Date;
  to?: Date;
  page?: number;
  limit?: number;
}
