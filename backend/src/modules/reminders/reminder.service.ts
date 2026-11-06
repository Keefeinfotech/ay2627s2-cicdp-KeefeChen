/**
 * File Name: reminder.service.ts
 * Description: Service logic for managing reminders.
 * Author: Keefe Chen
 */

import { Reminder } from "./reminder.model.js";

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
    return reminder.save();
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