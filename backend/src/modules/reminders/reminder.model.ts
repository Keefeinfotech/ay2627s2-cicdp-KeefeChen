/**
 * File Name: reminder.model.ts
 * Description: Mongoose schema and model for reminders.
 * Author: Keefe Chen
 */

import mongoose, { Schema } from "mongoose";

const reminderSchema = new Schema(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },
    dueAt: {
      type: Date,
      required: true,
    },
    completed: {
      type: Boolean,
      default: false,
    },
    completedAt: {
      type: Date,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  {
    timestamps: true,
    versionKey: false,
  },
);

/** Mongoose indexes */
reminderSchema.index({ userId: 1, dueAt: 1 });
reminderSchema.index({ completed: 1 });

/** Mongoose Model */
export const Reminder = mongoose.model("Reminder", reminderSchema);
