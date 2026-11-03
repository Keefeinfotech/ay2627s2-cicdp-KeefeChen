
/**
 * File Name: task.model.ts
 * Description: Defines the MongoDB task schema, lifecycle hooks, state transitions, and indexes.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type Model } from "mongoose";

import {
  TASK_PRIORITIES,
  TASK_STATUSES,
  type TaskRecord,
  type TaskStatus,
} from "./task.types.js";

// ============================================================================
// TASK SCHEMA
// ============================================================================

const taskSchema = new Schema<TaskRecord>(
  {
    /**
     * UUID-based primary key.
     */
    _id: {
      type: String,
      default: () => randomUUID(),
      immutable: true,
    },

    /**
     * Owner ID assigned by authentication middleware.
     */
    userId: {
      type: String,
      required: true,
      immutable: true,
    },

    title: {
      type: String,
      required: true,
      trim: true,
      minlength: 1,
      maxlength: 150,
    },

    description: {
      type: String,
      default: null,
      maxlength: 5000,
    },

    course: {
      type: String,
      default: "",
      trim: true,
      maxlength: 120,
    },

    reminderAt: {
      type: Date,
      default: null,
    },

    status: {
      type: String,
      enum: TASK_STATUSES,
      default: "todo",
      required: true,
    },

    priority: {
      type: String,
      enum: TASK_PRIORITIES,
      default: "medium",
      required: true,
    },

    dueDate: {
      type: Date,
      default: null,
    },

    completedAt: {
      type: Date,
      default: null,
    },

    /**
     * Soft-deletion timestamp.
     * Excluded from query results by default.
     */
    deletedAt: {
      type: Date,
      default: null,
      select: false,
    },
  },
  {
    timestamps: true,
    versionKey: false,
    strict: "throw",

    toJSON: {
      transform: (_document, result: Record<string, unknown>) => {
        delete result.deletedAt;
        return result;
      },
    },
  }
);

// ============================================================================
// INDEXES
// ============================================================================

/**
 * 1. User task listing.
 * Supports retrieving active tasks sorted by creation date.
 */
taskSchema.index(
  { userId: 1, deletedAt: 1, createdAt: -1 },
  {
    name: "ix_tasks_user_active_created",
  }
);

/**
 * 2. Status and due-date filtering.
 * Supports dashboard queries and overdue task filtering.
 */
taskSchema.index(
  { userId: 1, deletedAt: 1, status: 1, dueDate: 1 },
  {
    name: "ix_tasks_user_active_status_due",
  }
);

/**
 * 3. Priority filtering.
 * Supports retrieving tasks by priority and creation date.
 */
taskSchema.index(
  { userId: 1, deletedAt: 1, priority: 1, createdAt: -1 },
  {
    name: "ix_tasks_user_active_priority_created",
  }
);

/**
 * 4. User-scoped text search.
 * Requires userId equality when performing text searches.
 */
taskSchema.index(
  {
    userId: 1,
    title: "text",
    description: "text",
  },
  {
    name: "ix_tasks_user_text_search",
    weights: {
      title: 10,
      description: 2,
    },
  }
);

// ============================================================================
// LIFECYCLE HOOKS
// ============================================================================

/**
 * Automatically maintains completedAt when a document is saved.
 */
taskSchema.pre("save", function () {
  if (!this.isModified("status")) {
    return;
  }

  if (this.status === "completed") {
    if (!this.completedAt) {
      this.completedAt = new Date();
    }
  } else {
    this.completedAt = null;
  }
});

/**
 * Maintains completedAt for findOneAndUpdate operations.
 *
 * The existing document is checked so completedAt is only
 * generated when the task transitions into completed status.
 */
taskSchema.pre("findOneAndUpdate", async function () {
  const update = this.getUpdate();

  if (!update || Array.isArray(update)) {
    return;
  }

  const updateDocument = update as Record<string, unknown>;

  const setUpdate = updateDocument.$set as
    | Record<string, unknown>
    | undefined;

  const status = (
    setUpdate?.status ?? updateDocument.status
  ) as TaskStatus | undefined;

  if (!status) {
    return;
  }

  const currentTask = await this.model
    .findOne(this.getQuery())
    .select("status completedAt")
    .lean()
    .exec();

  if (!currentTask) {
    return;
  }

  const completionTimestamp =
    status === "completed"
      ? currentTask.status === "completed"
        ? currentTask.completedAt ?? new Date()
        : new Date()
      : null;

  if (setUpdate) {
    this.setUpdate({
      ...updateDocument,
      $set: {
        ...setUpdate,
        completedAt: completionTimestamp,
      },
    });
  } else {
    this.setUpdate({
      ...updateDocument,
      completedAt: completionTimestamp,
    });
  }
});

// ============================================================================
// MODEL EXPORT
// ============================================================================

export const Task: Model<TaskRecord> =
  (mongoose.models.Task as Model<TaskRecord>) ??
  mongoose.model<TaskRecord>("Task", taskSchema);
