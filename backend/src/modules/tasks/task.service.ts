/**
 * File Name: task.service.ts
 * Description: Implements task business rules and ownership enforcement.
 * Author: Keefe Chen
 */

import { AppError } from "../../../src/shared/utils/AppError";

import { taskRepository } from "./task.repository.js";

import type {
  CreateTaskInput,
  ListTasksInput,
  TaskRecord,
  UpdateTaskInput,
} from "./task.types.js";

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

    return taskRepository.create(userId, input);
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
    input: ListTasksInput
  ) {
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