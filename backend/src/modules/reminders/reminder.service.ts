/**
 * File Name: reminder.service.ts
 * Description: Service logic for managing reminders.
 * Author: Keefe Chen
 */

import { Reminder } from "./reminder.model.js";
import { User } from "../users/user.model.js";
import { enqueue } from "../../shared/jobs/index.js";
import logger from "../../config/logger.js";

export const reminderService = {
  /** Get all reminders for a user */
  async findAll(userId: string) {
    return Reminder.find({ userId }).sort({ dueAt: 1 });
  },

  /** Get a single reminder by ID */
  async findById(id: string) {
    return Reminder.findById(id);
  },

  /** Create a new reminder */
  async create(userId: string, message: string, dueAt: Date) {
    const reminder = new Reminder({
      userId,
      message,
      dueAt,
    });
    const saved = await reminder.save();

    // Best-effort notification through the notification-service prototype,
    // delivered via the background job queue (fail-open).
    try {
      const user = await User.findById(userId).select("email").lean();
      const email = (user as { email?: string } | null)?.email;
      if (email) {
        enqueue("notification.send", {
          to: email,
          channel: "email",
          subject: "Reminder created",
          message: `Reminder: ${message}`,
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

  /** Mark a reminder as completed */
  async complete(id: string) {
    const reminder = await Reminder.findById(id);
    if (!reminder) return null;

    reminder.completed = true;
    reminder.completedAt = new Date();
    return reminder.save();
  },

  /** Delete a reminder */
  async delete(id: string) {
    return Reminder.findByIdAndDelete(id);
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
