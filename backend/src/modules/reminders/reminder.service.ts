/**
 * File Name: reminder.service.ts
 * Description: Service logic for managing reminders. All queries are scoped
 *              by the owning user (BOLA prevention). Completing a recurring
 *              reminder spawns the next occurrence so reminders are not lost.
 * Author: Keefe Chen
 */

import { Reminder } from "./reminder.model.js";
import { User } from "../users/user.model.js";
import { enqueue } from "../../shared/jobs/index.js";
import logger from "../../config/logger.js";

import type {
  ReminderCreateInput,
  ReminderRecurrence,
  ReminderUpdateInput,
} from "./reminder.types.js";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * Computes the next occurrence for a recurring reminder in UTC.
 * MongoDB stores Date values as UTC instants. Using local getters/setters here
 * would shift a schedule by the server's timezone offset (and across DST),
 * which is especially harmful for daily reminders.
 */
const nextOccurrence = (dueAt: Date, recurrence: ReminderRecurrence): Date => {
  const next = new Date(dueAt);
  if (recurrence === "daily") next.setUTCDate(next.getUTCDate() + 1);
  else if (recurrence === "weekly") next.setUTCDate(next.getUTCDate() + 7);
  else if (recurrence === "monthly") next.setUTCMonth(next.getUTCMonth() + 1);
  else return dueAt;

  // If the computed occurrence is still in the past (e.g. completing a stale
  // reminder), keep rolling forward until it is in the future.
  const now = Date.now();
  let guard = 0;
  while (next.getTime() <= now && guard < 400) {
    if (recurrence === "daily") next.setUTCDate(next.getUTCDate() + 1);
    else if (recurrence === "weekly") next.setUTCDate(next.getUTCDate() + 7);
    else next.setUTCMonth(next.getUTCMonth() + 1);
    guard += 1;
  }
  return next;
};

export const reminderService = {
  /** Get all reminders for a user */
  async findAll(userId: string) {
    return Reminder.find({ userId }).sort({ dueAt: 1 });
  },

  /** Get a single reminder owned by the user. */
  async findById(id: string, userId: string) {
    return Reminder.findOne({ _id: id, userId });
  },

  /** Reminders for a specific task owned by the user. */
  async findByTask(userId: string, taskId: string) {
    return Reminder.find({ userId, taskId }).sort({ dueAt: 1 });
  },

  /** Upcoming pending reminders within the given number of days. */
  async upcoming(userId: string, days: number) {
    const clamped = Math.min(Math.max(Math.trunc(days) || 7, 1), 90);
    const horizon = new Date(Date.now() + clamped * MS_PER_DAY);

    return Reminder.find({
      userId,
      completed: false,
      enabled: true,
      dueAt: { $lte: horizon },
    })
      .sort({ dueAt: 1 })
      .limit(100);
  },

  /** Create a new reminder */
  async create(userId: string, input: ReminderCreateInput) {
    const reminder = new Reminder({
      userId,
      message: input.message,
      dueAt: new Date(input.dueAt),
      taskId: input.taskId ?? null,
      recurrence: input.recurrence ?? "none",
      enabled: input.enabled ?? true,
    });
    const saved = await reminder.save();

    // Best-effort notification through the notification-service,
    // delivered via the background job queue (fail-open).
    try {
      const user = await User.findById(userId).select("email").lean();
      const email = (user as { email?: string } | null)?.email;
      if (email) {
        enqueue("notification.send", {
          to: email,
          channel: "email",
          subject: "Reminder created",
          message: `Reminder: ${saved.message}`,
          userId,
          type: "reminder",
          entityId: String(saved._id),
        });
      }
    } catch (error) {
      logger.warn("reminder.notification_enqueue_failed", {
        userId,
        error: error instanceof Error ? error.message : String(error),
      });
    }

    return saved;
  },

  /** Partially update a reminder owned by the user. */
  async update(id: string, userId: string, input: ReminderUpdateInput) {
    const reminder = await Reminder.findOne({ _id: id, userId });
    if (!reminder) return null;

    if (input.message !== undefined) reminder.message = input.message;
    if (input.dueAt !== undefined) reminder.dueAt = new Date(input.dueAt);
    if (input.taskId !== undefined) reminder.taskId = input.taskId;
    if (input.recurrence !== undefined) reminder.recurrence = input.recurrence;
    if (input.enabled !== undefined) reminder.enabled = input.enabled;
    if (input.completed !== undefined) {
      reminder.completed = input.completed;
      reminder.completedAt = input.completed ? new Date() : undefined;
    }

    return reminder.save();
  },

  /** Update only the enabled/status flag. */
  async setEnabled(id: string, userId: string, enabled: boolean) {
    return Reminder.findOneAndUpdate(
      { _id: id, userId },
      { $set: { enabled } },
      { new: true },
    );
  },

  /**
   * Mark a reminder as completed. Completing a recurring reminder spawns the
   * next occurrence instead of dead-ending the series.
   */
  async complete(id: string, userId: string) {
    const reminder = await Reminder.findOne({ _id: id, userId });
    if (!reminder) return null;

    reminder.completed = true;
    reminder.completedAt = new Date();
    const saved = await reminder.save();

    if (saved.recurrence !== "none") {
      const existingNext = await Reminder.findOne({
        userId,
        message: saved.message,
        taskId: saved.taskId ?? null,
        recurrence: saved.recurrence,
        completed: false,
        dueAt: { $gt: saved.completedAt },
      })
        .select("_id")
        .lean();

      if (!existingNext) {
        await Reminder.create({
          userId,
          taskId: saved.taskId ?? null,
          message: saved.message,
          dueAt: nextOccurrence(saved.dueAt, saved.recurrence),
          recurrence: saved.recurrence,
          enabled: saved.enabled,
        });
      }
    }

    return saved;
  },

  /** Delete a reminder owned by the user. */
  async delete(id: string, userId: string) {
    return Reminder.findOneAndDelete({ _id: id, userId });
  },

  /** Get pending reminders due before a certain date */
  async findPending(userId: string, beforeDate: Date) {
    return Reminder.find({
      userId,
      completed: false,
      dueAt: { $lte: beforeDate },
    }).sort({ dueAt: 1 });
  },
};
