/**
 * File Name: reminder.model.ts
 * Description: Mongoose schema and model for reminders.
 *              Extended (backwards compatible) with task linkage, recurrence
 *              and an enabled flag.
 *
 *              userId is a String UUID to match users._id and tasks.userId.
 *              The previous ObjectId type could not reference UUID users and
 *              caused cast failures on create and lookups. See
 *              scripts/migrate-reminder-user-ids.ts for the data migration.
 *              _id deliberately stays an ObjectId: reminders are not part of
 *              the offline sync protocol, so no client-generated id is needed.
 * Author: Keefe Chen
 */

import mongoose, { Schema } from "mongoose";

export const REMINDER_RECURRENCES = [
  "none",
  "daily",
  "weekly",
  "monthly",
] as const;

export type ReminderRecurrence = (typeof REMINDER_RECURRENCES)[number];

const reminderSchema = new Schema(
  {
    userId: {
      // Must match users._id (String UUID). `ref` is kept so populate() works.
      type: String,
      ref: "User",
      required: true,
    },
    taskId: {
      // Optional link to a task (task UUIDs are stored as strings).
      // No single-field index: the compound (taskId, userId) index below
      // covers every task-scoped lookup with less write overhead.
      type: String,
      default: null,
    },
    message: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500,
    },
    dueAt: {
      type: Date,
      required: true,
    },
    recurrence: {
      type: String,
      enum: REMINDER_RECURRENCES,
      default: "none",
    },
    enabled: {
      type: Boolean,
      default: true,
    },
    completed: {
      type: Boolean,
      default: false,
    },
    completedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

/** Mongoose indexes — based on the actual query patterns below. */
reminderSchema.index({ userId: 1, dueAt: 1 });
reminderSchema.index({ userId: 1, completed: 1, dueAt: 1 });
reminderSchema.index({ userId: 1, enabled: 1, dueAt: 1 });
reminderSchema.index({ taskId: 1, userId: 1 });

/** Mongoose Model */
export const Reminder = mongoose.model("Reminder", reminderSchema);
