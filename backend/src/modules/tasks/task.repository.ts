
/**
 * File Name: task.repository.ts
 * Description: Encapsulates MongoDB persistence operations for tasks.
 * Author: Keefe Chen
 */

import { Task } from "./task.model.js";

import type {
  CreateTaskInput,
  OffsetPaginationInput,
  OffsetPaginatedTasks,
  TaskRecord,
  UpdateTaskInput,
  TaskSortField,
} from "./task.types.js";

export const taskRepository = {
  /**
   * Creates a task belonging to the specified user.
   */
  async create(
    userId: string,
    input: CreateTaskInput
  ): Promise<TaskRecord> {
    const task = await Task.create({
      ...(input.id ? { _id: input.id } : {}),
      userId,
      title: input.title,
      description: input.description ?? null,
      course: input.course ?? "",
      reminderAt: input.reminderAt ?? null,
      priority: input.priority ?? "medium",
      dueDate: input.dueDate ?? null,
    });

    return task.toObject() as TaskRecord;
  },

  /**
   * Retrieves a task owned by the specified user.
   */
  async findByIdForUser(
    taskId: string,
    userId: string
  ): Promise<TaskRecord | null> {
    return Task.findOne({
      _id: taskId,
      userId,
      deletedAt: null,
    })
      .lean<TaskRecord>()
      .exec();
  },

  /**
   * Retrieves a user's tasks using filters and offset pagination.
   */
  async listForUser(
    userId: string,
    input: OffsetPaginationInput
  ): Promise<OffsetPaginatedTasks> {
    // Apply pagination defaults.
    const page = input.page ?? 1;
    const limit = input.limit ?? 20;

    // Build the base query.
    const filter: Record<string, unknown> = {
      userId,
    };

    // Exclude soft-deleted tasks by default.
    if (!input.includeDeleted) {
      filter.deletedAt = null;
    }

    // Apply text search.
    if (input.search?.trim()) {
      filter.$text = {
        $search: input.search.trim(),
      };
    }

    // Apply status filtering.
    if (input.status) {
      filter.status = Array.isArray(input.status)
        ? { $in: input.status }
        : input.status;
    }

    // Apply priority filtering.
    if (input.priority) {
      filter.priority = Array.isArray(input.priority)
        ? { $in: input.priority }
        : input.priority;
    }

    // Apply due-date filtering.
    if (input.dueBefore || input.dueAfter) {
      const dueDate: Record<string, Date> = {};

      if (input.dueAfter) {
        dueDate.$gte = input.dueAfter;
      }

      if (input.dueBefore) {
        dueDate.$lte = input.dueBefore;
      }

      filter.dueDate = dueDate;
    }

    // Apply completion-date filtering.
    if (input.completedBefore || input.completedAfter) {
      const completedAt: Record<string, Date> = {};

      if (input.completedAfter) {
        completedAt.$gte = input.completedAfter;
      }

      if (input.completedBefore) {
        completedAt.$lte = input.completedBefore;
      }

      filter.completedAt = completedAt;
    }

    // Determine sorting.
    const sortBy: TaskSortField = input.sortBy ?? "createdAt";
    const sortOrder = input.sortOrder === "asc" ? 1 : -1;

    const sort: Record<string, 1 | -1> = {
      [sortBy]: sortOrder,
      _id: 1,
    };

    // Calculate the number of records to skip.
    const skip = (page - 1) * limit;

    // Retrieve tasks and total count concurrently.
    const [items, totalItems] = await Promise.all([
      Task.find(filter)
        .sort(sort)
        .skip(skip)
        .limit(limit)
        .lean<TaskRecord[]>()
        .exec(),

      Task.countDocuments(filter).exec(),
    ]);

    // Calculate pagination metadata.
    const totalPages = Math.ceil(totalItems / limit);

    return {
      type: "offset",
      items,
      pagination: {
        page,
        limit,
        totalItems,
        totalPages,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
      },
    };
  },

  /**
   * Updates a task only if it belongs to the specified user.
   * Completion timestamps are maintained by the model lifecycle hook.
   */
  async updateForUser(
    taskId: string,
    userId: string,
    input: UpdateTaskInput
  ): Promise<TaskRecord | null> {
    return Task.findOneAndUpdate(
      {
        _id: taskId,
        userId,
        deletedAt: null,
      },
      {
        $set: input,
      },
      {
        new: true,
        runValidators: true,
      }
    )
      .lean<TaskRecord>()
      .exec();
  },

  /**
   * Soft-deletes a task instead of permanently removing it.
   */
  async softDeleteForUser(
    taskId: string,
    userId: string
  ): Promise<boolean> {
    const result = await Task.updateOne(
      {
        _id: taskId,
        userId,
        deletedAt: null,
      },
      {
        $set: {
          deletedAt: new Date(),
          status: "archived",
        },
      }
    ).exec();

    return result.modifiedCount === 1;
  },
};
