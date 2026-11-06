/**
 * File Name: task.service.ts
 * Description: Implements task business rules and ownership enforcement.
 * Author: Keefe Chen
 */

import { AppError } from "../../../src/shared/utils/AppError";

import { taskRepository } from "./task.repository.js";
import { requireGroupMembership } from "../groups/shared/membership.js";
import { Member } from "../groups/member/member.model.js";

import type {
  CreateTaskInput,
  OffsetPaginationInput,
  OffsetPaginatedTasks,
  TaskRecord,
  UpdateTaskInput,
} from "./task.types.js";

/**
 * Enforces the group assignment contract on the write path:
 *
 * * a caller may only attach a task to a group they actively belong to,
 * * an assignee must be an active member of that group, and a task cannot
 *   name an assignee without a group to scope the assignment.
 *
 * Passing `null`/`undefined` for a value means "not set" and skips that check.
 */
async function assertValidAssignment(
  userId: string,
  groupId: string | null | undefined,
  assigneeId: string | null | undefined,
): Promise<void> {
  if (groupId) {
    await requireGroupMembership(groupId, userId);
  }

  if (assigneeId) {
    if (!groupId) {
      throw new AppError(
        422,
        "ASSIGNEE_REQUIRES_GROUP",
        "A task assigned to a member must name that member's group.",
      );
    }

    const membership = await Member.findOne({
      groupId,
      userId: assigneeId,
      status: "ACTIVE",
    })
      .select("_id")
      .lean();

    if (!membership) {
      throw new AppError(
        422,
        "ASSIGNEE_NOT_IN_GROUP",
        "The assignee is not an active member of that group.",
      );
    }
  }
}

export const taskService = {
  /**
   * Creates a task for the authenticated user.
   */
  async createTask(
    userId: string,
    input: CreateTaskInput
  ): Promise<TaskRecord> {
    if (!userId) {
      throw new AppError(
        401,
        "UNAUTHENTICATED",
        "Authentication is required."
      );
    }

    await assertValidAssignment(userId, input.groupId, input.assigneeId);

    // The client supplies a stable task UUID when replaying its offline sync
    // queue. Treat a repeated create for that owner as the same operation.
    if (input.id) {
      const existing = await taskRepository.findByIdForUser(input.id, userId);
      if (existing) return existing;
    }

    try {
      return await taskRepository.create(userId, input);
    } catch (error) {
      // Two retries can pass the preflight lookup at the same time. The task
      // UUID's unique index is the final idempotency guard for that race.
      if (input.id && typeof error === "object" && error !== null && "code" in error && error.code === 11000) {
        const existing = await taskRepository.findByIdForUser(input.id, userId);
        if (existing) return existing;
      }
      throw error;
    }
  },

  /**
   * Retrieves a single task.
   */
  async getTask(
    userId: string,
    taskId: string
  ): Promise<TaskRecord> {
    const task = await taskRepository.findByIdForUser(
      taskId,
      userId
    );

    if (!task) {
      throw new AppError(
        404,
        "TASK_NOT_FOUND",
        "Task was not found."
      );
    }

    return task;
  },

  /**
   * Retrieves tasks with filtering and pagination.
   */
  async listTasks(
    userId: string,
    input: OffsetPaginationInput
  ): Promise<OffsetPaginatedTasks> {
    if (
      input.dueAfter &&
      input.dueBefore &&
      input.dueAfter > input.dueBefore
    ) {
      throw new AppError(
        400,
        "INVALID_DATE_RANGE",
        "dueAfter must be earlier than or equal to dueBefore."
      );
    }

    return taskRepository.listForUser(userId, input);
  },

  /**
   * Updates an existing task.
   */
  async updateTask(
    userId: string,
    taskId: string,
    input: UpdateTaskInput
  ): Promise<TaskRecord> {
    const current = await taskRepository.findByIdForUser(taskId, userId);

    if (!current) {
      throw new AppError(
        404,
        "TASK_NOT_FOUND",
        "Task was not found."
      );
    }

    const effectiveGroupId = input.groupId === undefined
      ? current.groupId
      : input.groupId;
    const effectiveAssigneeId = input.assigneeId === undefined
      ? current.assigneeId
      : input.assigneeId;

    await assertValidAssignment(userId, effectiveGroupId, effectiveAssigneeId);

    const task = await taskRepository.updateForUser(
      taskId,
      userId,
      input
    );

    if (!task) {
      throw new AppError(
        404,
        "TASK_NOT_FOUND",
        "Task was not found."
      );
    }

    return task;
  },

  /**
   * Soft-deletes an existing task.
   */
  async deleteTask(
    userId: string,
    taskId: string
  ): Promise<void> {
    const deleted = await taskRepository.softDeleteForUser(
      taskId,
      userId
    );

    if (!deleted) {
      throw new AppError(
        404,
        "TASK_NOT_FOUND",
        "Task was not found."
      );
    }
  },
};
