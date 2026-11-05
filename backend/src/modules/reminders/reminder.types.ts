/**
 * File Name: reminder.types.ts
 * Description: Type definitions for reminder data.
 * Author: Keefe Chen
 */

export interface Reminder {
  _id: string;
  userId: string;
  message: string;
  dueAt: Date;
  completed: boolean;
  completedAt: Date | null;
  createdAt: Date;
}

export interface ReminderCreateInput {
  message: string;
  dueAt: string | Date;
}

export interface ReminderProgressResponse {
  total: number;
  completed: number;
  pending: number;
  overdue: number;
}