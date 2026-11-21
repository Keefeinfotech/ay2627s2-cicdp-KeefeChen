/**
 * File Name: task.repository.ts
 * Description: Encapsulates MongoDB persistence operations for tasks.
 * Author: Keefe Chen
 */

import { requireString } from "../../shared/utils/queryGuard.js";

import { Task } from "./task.model.js";

import type {
  CreateTaskInput,
  OffsetPaginationInput,
  OffsetPaginatedTasks,
  TaskRecord,
  UpdateTaskInput,
  TaskSortField,
} from "./task.types.js";

/**
 * Builds an update document from an allow-list of task fields. Property names
 * are fixed in code and every value is coerced to a scalar before it reaches
 * MongoDB, so a client cannot smuggle query operators into `$set`.
 */
const taskUpdateFields = (input: UpdateTaskInput): Record<string, unknown> => {
  const set: Record<string, unknown> = {};
  if (input.title !== undefined)
    set.title = requireString(input.title, "title");
  if (input.description !== undefined) {
    set.description =
      input.description === null
        ? null
        : requireString(input.description, "description");
  }
  if (input.course !== undefined) {
    set.course = requireString(input.course, "course");
  }
  if (input.tags !== undefined) {
    set.tags = input.tags.map((tag) => requireString(tag, "tag"));
  }
  if (input.groupId !== undefined) {
    set.groupId =
      input.groupId === null ? null : requireString(input.groupId, "group ID");
  }
  if (input.assigneeId !== undefined) {
    set.assigneeId =
      input.assigneeId === null
        ? null
        : requireString(input.assigneeId, "assignee ID");
  }
  if (input.assigneeName !== undefined) {
    set.assigneeName =
      input.assigneeName === null
        ? null
        : requireString(input.assigneeName, "assignee name");
  }
  if (input.reminderAt !== undefined) {
    set.reminderAt =
      input.reminderAt === null ? null : new Date(input.reminderAt);
  }
  if (input.priority !== undefined) {
    set.priority = requireString(input.priority, "priority");
  }
  if (input.status !== undefined) {
    set.status = requireString(input.status, "status");
  }
  if (input.dueDate !== undefined) {
    set.dueDate = input.dueDate === null ? null : new Date(input.dueDate);
  }
  return set;
};

export const taskRepository = {
  /**
   * Creates a task belonging to the specified user.
   */
  async create(userId: string, input: CreateTaskInput): Promise<TaskRecord> {
    const task = await Task.create({
      ...(input.id ? { _id: input.id } : {}),
      userId,
      title: input.title,
      description: input.description ?? null,
      course: input.course ?? "",
      tags: input.tags ?? [],
      groupId: input.groupId ?? null,
      assigneeId: input.assigneeId ?? null,
      assigneeName: input.assigneeName ?? null,
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
    userId: string,
  ): Promise<TaskRecord | null> {
    return Task.findOne({
      _id: { $eq: taskId },
      userId: { $eq: userId },
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
    input: OffsetPaginationInput,
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
   *
   * When the caller passes `expectedUpdatedAt`, the update is applied only
   * when the persisted `updatedAt` still matches it (compare-and-swap). A
   * mismatch returns null so the service can answer 409 `TASK_CONFLICT`
   * instead of silently overwriting a concurrent change.
   */
  async updateForUser(
    taskId: string,
    userId: string,
    input: UpdateTaskInput,
  ): Promise<TaskRecord | null> {
    const { expectedUpdatedAt, ...fields } = input;
    const filter: Record<string, unknown> = {
      _id: { $eq: taskId },
      userId: { $eq: userId },
      deletedAt: null,
    };

    if (expectedUpdatedAt) {
      // $eq keeps the client-supplied timestamp a literal value, not a query.
      filter.updatedAt = { $eq: expectedUpdatedAt };
    }

    return Task.findOneAndUpdate(
      filter,
      {
        $set: taskUpdateFields(fields),
      },
      {
        new: true,
        runValidators: true,
      },
    )
      .lean<TaskRecord>()
      .exec();
  },

  /**
   * Soft-deletes a task instead of permanently removing it.
   */
  async softDeleteForUser(taskId: string, userId: string): Promise<boolean> {
    const result = await Task.updateOne(
      {
        _id: { $eq: taskId },
        userId: { $eq: userId },
        deletedAt: null,
      },
      {
        $set: {
          deletedAt: new Date(),
          status: "archived",
        },
      },
    ).exec();

    return result.modifiedCount === 1;
  },
};
