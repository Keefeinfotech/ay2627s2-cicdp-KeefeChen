/**
 * File Name: reminder.model.ts
 * Description: Mongoose schema and model for reminders.
 *              Extended (backwards compatible) with task linkage, recurrence
 *              and an enabled flag.
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
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    taskId: {
      // Optional link to a task (task UUIDs are stored as strings).
      type: String,
      default: null,
      index: true,
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
