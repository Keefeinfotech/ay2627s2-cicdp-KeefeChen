/**
 * File Name: task.service.ts
 * Description: Implements task business rules and ownership enforcement.
 * Author: Keefe Chen
 */

import { AppError } from "../../shared/utils/AppError.js";

import { taskRepository } from "./task.repository.js";
import { requireGroupMembership } from "../groups/shared/membership.js";
import { Member } from "../groups/member/member.model.js";
import { enqueue } from "../../shared/jobs/index.js";

import type {
  CreateTaskInput,
  OffsetPaginationInput,
  OffsetPaginatedTasks,
  TaskRecord,
  TaskStatus,
  UpdateTaskInput,
} from "./task.types.js";

export interface BulkFailure {
  index: number;
  id: string | null;
  error: string;
}

export interface BulkOperationResult {
  succeeded: unknown[];
  failed: BulkFailure[];
}

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
    input: CreateTaskInput,
  ): Promise<TaskRecord> {
    if (!userId) {
      throw new AppError(401, "UNAUTHENTICATED", "Authentication is required.");
    }

    await assertValidAssignment(userId, input.groupId, input.assigneeId);

    // The client supplies a stable task UUID when replaying its offline sync
    // queue. Treat a repeated create for that owner as the same operation.
    if (input.id) {
      const existing = await taskRepository.findByIdForUser(input.id, userId);
      if (existing) return existing;
    }

    const created = await (async () => {
      try {
        return await taskRepository.create(userId, input);
      } catch (error) {
        // Two retries can pass the preflight lookup at the same time. The task
        // UUID's unique index is the final idempotency guard for that race.
        if (
          input.id &&
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          error.code === 11000
        ) {
          const existing = await taskRepository.findByIdForUser(
            input.id,
            userId,
          );
          if (existing) return existing;
        }
        throw error;
      }
    })();

    enqueue("analytics.invalidate", { userId });
    return created;
  },

  /**
   * Retrieves a single task.
   */
  async getTask(userId: string, taskId: string): Promise<TaskRecord> {
    const task = await taskRepository.findByIdForUser(taskId, userId);

    if (!task) {
      throw new AppError(404, "TASK_NOT_FOUND", "Task was not found.");
    }

    return task;
  },

  /**
   * Retrieves tasks with filtering and pagination.
   */
  async listTasks(
    userId: string,
    input: OffsetPaginationInput,
  ): Promise<OffsetPaginatedTasks> {
    if (input.dueAfter && input.dueBefore && input.dueAfter > input.dueBefore) {
      throw new AppError(
        400,
        "INVALID_DATE_RANGE",
        "dueAfter must be earlier than or equal to dueBefore.",
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
    input: UpdateTaskInput,
  ): Promise<TaskRecord> {
    const current = await taskRepository.findByIdForUser(taskId, userId);

    if (!current) {
      throw new AppError(404, "TASK_NOT_FOUND", "Task was not found.");
    }

    // Optimistic concurrency: reject the update if the row changed since the
    // caller captured it (compare-and-swap). The same precondition is applied
    // atomically in the repository so a racing writer still cannot win.
    if (
      input.expectedUpdatedAt &&
      current.updatedAt.getTime() !== input.expectedUpdatedAt.getTime()
    ) {
      throw new AppError(
        409,
        "TASK_CONFLICT",
        "This task was changed on another device. Reload it and try again.",
      );
    }

    const effectiveGroupId =
      input.groupId === undefined ? current.groupId : input.groupId;
    const effectiveAssigneeId =
      input.assigneeId === undefined ? current.assigneeId : input.assigneeId;

    await assertValidAssignment(userId, effectiveGroupId, effectiveAssigneeId);

    const task = await taskRepository.updateForUser(taskId, userId, input);

    if (!task) {
      if (input.expectedUpdatedAt) {
        // Lost the compare-and-swap against a racing writer.
        throw new AppError(
          409,
          "TASK_CONFLICT",
          "This task was changed on another device. Reload it and try again.",
        );
      }
      throw new AppError(404, "TASK_NOT_FOUND", "Task was not found.");
    }

    enqueue("analytics.invalidate", { userId });
    return task;
  },

  /**
   * Bulk-creates tasks. Each task is validated independently and ownership
   * rules still apply; failures are reported per item.
   */
  async bulkCreateTasks(
    userId: string,
    inputs: CreateTaskInput[],
  ): Promise<BulkOperationResult> {
    const succeeded: unknown[] = [];
    const failed: BulkFailure[] = [];

    for (const [index, input] of inputs.entries()) {
      try {
        const task = await this.createTask(userId, input);
        succeeded.push(task);
      } catch (error) {
        failed.push({
          index,
          id: input.id ?? null,
          error:
            error instanceof AppError
              ? error.message
              : "Failed to create task.",
        });
      }
    }

    return { succeeded, failed };
  },

  /**
   * Bulk status update with per-task ownership enforcement.
   */
  async bulkUpdateStatus(
    userId: string,
    ids: string[],
    status: TaskStatus,
  ): Promise<BulkOperationResult> {
    const succeeded: string[] = [];
    const failed: BulkFailure[] = [];

    for (const [index, taskId] of ids.entries()) {
      try {
        await this.updateTask(userId, taskId, { status });
        succeeded.push(taskId);
      } catch (error) {
        failed.push({
          index,
          id: taskId,
          error:
            error instanceof AppError
              ? error.message
              : "Failed to update task.",
        });
      }
    }

    return { succeeded, failed };
  },

  /**
   * Bulk soft-delete with per-task ownership enforcement.
   */
  async bulkDeleteTasks(
    userId: string,
    ids: string[],
  ): Promise<BulkOperationResult> {
    const succeeded: string[] = [];
    const failed: BulkFailure[] = [];

    for (const [index, taskId] of ids.entries()) {
      try {
        await this.deleteTask(userId, taskId);
        succeeded.push(taskId);
      } catch (error) {
        failed.push({
          index,
          id: taskId,
          error:
            error instanceof AppError
              ? error.message
              : "Failed to delete task.",
        });
      }
    }

    return { succeeded, failed };
  },

  /**
   * Soft-deletes an existing task.
   */
  async deleteTask(userId: string, taskId: string): Promise<void> {
    const deleted = await taskRepository.softDeleteForUser(taskId, userId);

    if (!deleted) {
      throw new AppError(404, "TASK_NOT_FOUND", "Task was not found.");
    }

    enqueue("analytics.invalidate", { userId });
  },
};
