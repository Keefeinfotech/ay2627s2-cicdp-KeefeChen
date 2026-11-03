/**
 * File Name: session.service.ts
 * Description: Business rules for group study sessions.
 * Author: Keefe Chen
 */

import { AppError } from "../../shared/utils/AppError.js";
import { AUDIT_ACTIONS } from "../audit/audit.types.js";
import { auditService } from "../audit/audit.service.js";
import {
  GROUP_MANAGER_ROLES,
  requireGroupMembership,
} from "../groups/shared/membership.js";
import { sessionRepository } from "./session.repository.js";

import type { StudySessionDocument } from "./session.model.js";
import type {
  CreateSessionInput,
  ListSessionsQuery,
  SessionStatus,
  UpdateSessionInput,
} from "./session.types.js";

const canManage = (userId: string, session: StudySessionDocument): boolean =>
  userId === (session.createdBy as string | undefined);

export const sessionService = {
  /**
   * Schedules a study session for the group.
   */
  async create(
    groupId: string,
    userId: string,
    input: CreateSessionInput,
  ): Promise<StudySessionDocument> {
    const membership = await requireGroupMembership(groupId, userId);

    if (input.endsAt.getTime() <= input.startsAt.getTime()) {
      throw new AppError(
        400,
        "INVALID_SESSION_RANGE",
        "endsAt must be later than startsAt.",
      );
    }

    const session = await sessionRepository.create({
      groupId,
      title: input.title.trim(),
      description: input.description ?? null,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      location: input.location ?? null,
      maxAttendees: input.maxAttendees ?? null,
      createdBy: userId,
      attendeeIds: [userId],
    });

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_CREATED,
      targetType: "session",
      targetId: session._id,
      metadata: { startsAt: input.startsAt },
    });


    return session;
  },

  /**
   * Lists sessions for the group with optional filters.
   */
  async list(
    groupId: string,
    userId: string,
    query: ListSessionsQuery,
  ) {
    await requireGroupMembership(groupId, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    return sessionRepository.listByGroup(groupId, {
      status: query.status,
      from: query.from,
      to: query.to,
      page,
      limit,
    });
  },

  /**
   * Retrieves a single scheduled session.
   */
  async get(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<StudySessionDocument> {
    await requireGroupMembership(groupId, userId);

    const session = await sessionRepository.findById(sessionId);

    if (!session || session.groupId !== groupId) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found.",
      );
    }

    return session;
  },

  /**
   * Updates session details. The creator and group managers may edit.
   */
  async update(
    groupId: string,
    userId: string,
    sessionId: string,
    input: UpdateSessionInput,
  ): Promise<StudySessionDocument> {
    const [session, membership] = await Promise.all([
      sessionService.get(groupId, userId, sessionId),
      requireGroupMembership(groupId, userId),
    ]);

    const isManager = GROUP_MANAGER_ROLES.includes(membership.role);

    if (session.createdBy !== userId && !isManager) {
      throw new AppError(
        403,
        "SESSION_UPDATE_FORBIDDEN",
        "Only the session creator or group managers can update this session.",
      );
    }

    const startsAt = input.startsAt ?? session.startsAt;
    const endsAt = input.endsAt ?? session.endsAt;

    if (new Date(endsAt).getTime() <= new Date(startsAt).getTime()) {
      throw new AppError(
        400,
        "INVALID_SESSION_RANGE",
        "endsAt must be later than startsAt.",
      );
    }

    const data: UpdateSessionInput = {};

    if (input.title !== undefined) data.title = input.title.trim();
    if (input.description !== undefined) data.description = input.description;
    if (input.startsAt !== undefined) data.startsAt = input.startsAt;
    if (input.endsAt !== undefined) data.endsAt = input.endsAt;
    if (input.location !== undefined) data.location = input.location;

    const updated = await sessionRepository.update(
      sessionId,
      groupId,
      data as Record<string, unknown>,
    );

    if (!updated) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_UPDATED,
      targetType: "session",
      targetId: sessionId,
      metadata: { fields: Object.keys(data) },
    });

    return updated;
  },

  /**
   * Marks a session as cancelled so attendees stop expecting it.
   */
  async cancel(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<StudySessionDocument> {
    const session = await sessionService.get(groupId, userId, sessionId);

    if (session.status !== "scheduled") {
      throw new AppError(
        409,
        "SESSION_NOT_SCHEDULABLE",
        "Only scheduled sessions can be cancelled.",
      );
    }

    const cancelled = await sessionRepository.update(sessionId, groupId, {
      status: "cancelled",
    });

    if (!cancelled) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_CANCELLED,
      targetType: "session",
      targetId: sessionId,
    });

    return cancelled;
  },

  /**
   * Marks a session as completed after it has run.
   */
  async complete(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<StudySessionDocument> {
    const session = await sessionService.get(groupId, userId, sessionId);

    if (session.status !== "scheduled") {
      throw new AppError(
        409,
        "SESSION_NOT_SCHEDULABLE",
        "Only scheduled sessions can be completed.",
      );
    }

    const completed = await sessionRepository.update(sessionId, groupId, {
      status: "completed",
    });

    if (!completed) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_COMPLETED,
      targetType: "session",
      targetId: sessionId,
    });

    return completed;
  },

  /**
   * Joins a scheduled session and enforces the optional capacity limit.
   */
  async join(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<StudySessionDocument> {
    await requireGroupMembership(groupId, userId);

    const session = await sessionService.get(groupId, userId, sessionId);

    if (session.status !== "scheduled") {
      throw new AppError(
        409,
        "SESSION_NOT_SCHEDULABLE",
        "Only scheduled sessions accept attendees.",
      );
    }

    if (session.attendeeIds?.includes(userId)) {
      return session;
    }

    const joined = await sessionRepository.join(
      sessionId,
      groupId,
      userId,
      session.maxAttendees ?? null,
    );

    if (!joined) {
      throw new AppError(
        409,
        "SESSION_FULL",
        "This session is already full.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_JOINED,
      targetType: "session",
      targetId: sessionId,
    });

    return joined;
  },

  /**
   * Leaves a scheduled session.
   */
  async leave(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<StudySessionDocument> {
    await requireGroupMembership(groupId, userId);

    const left = await sessionRepository.leave(sessionId, groupId, userId);

    if (!left) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found or you are not attending it.",
      );
    }

    await auditService.record({
      groupId,
      actorId: userId,
      action: AUDIT_ACTIONS.SESSION_LEFT,
      targetType: "session",
      targetId: sessionId,
    });

    return left;
  },

  /**
   * Deletes a session permanently. The creator or managers may delete.
   */
  async delete(
    groupId: string,
    userId: string,
    sessionId: string,
  ): Promise<void> {
    const [session, membership] = await Promise.all([
      sessionService.get(groupId, userId, sessionId),
      requireGroupMembership(groupId, userId),
    ]);

    const isManager = GROUP_MANAGER_ROLES.includes(membership.role);

    if (session.createdBy !== userId && !isManager) {
      throw new AppError(
        403,
        "SESSION_UPDATE_FORBIDDEN",
        "Only the session creator or group managers can delete this session.",
      );
    }

    const removed = await sessionRepository.remove(sessionId, groupId);

    if (!removed) {
      throw new AppError(
        404,
        "SESSION_NOT_FOUND",
        "Study session was not found.",
      );
    }
  },
};


