/**
 * File Name: reminder.types.ts
 * Description: Type definitions for reminder data.
 */

import type { ReminderRecurrence } from "./reminder.model.js";

export type { ReminderRecurrence };

export interface Reminder {
  _id: string;
  userId: string;
  taskId: string | null;
  message: string;
  dueAt: Date;
  recurrence: ReminderRecurrence;
  enabled: boolean;
  completed: boolean;
  completedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ReminderCreateInput {
  message: string;
  dueAt: string | Date;
  taskId?: string | null;
  recurrence?: ReminderRecurrence;
  enabled?: boolean;
}

export interface ReminderUpdateInput {
  message?: string;
  dueAt?: string | Date;
  taskId?: string | null;
  recurrence?: ReminderRecurrence;
  enabled?: boolean;
  completed?: boolean;
}

export interface ReminderProgressResponse {
  total: number;
  completed: number;
  pending: number;
  overdue: number;
}
