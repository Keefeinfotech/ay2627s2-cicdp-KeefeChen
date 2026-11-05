/**
 * File Name: sync.types.ts
 * Description: Types for the offline-first change feed.
 * Author: Keefe Chen
 */

import { Request } from 'express';

export interface TaskChange {
  id: string;
  userId: string;
  title: string;
  description: string | null;
  course: string;
  reminderAt: Date | null;
  status: string;
  priority: string;
  dueDate: Date | null;
  completedAt: Date | null;
  deletedAt: Date | null;
  updatedAt: Date;
  createdAt: Date;
}

export interface SyncChangesResult {
  serverTime: Date;
  since: Date;
  tasks: TaskChange[];
}

export interface PushChangesDTO {
  userId: string;
  changes: Partial<TaskChange>[];
}

export interface AuthenticatedUser {
  id: string;
  email?: string;
  [key: string]: unknown;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}