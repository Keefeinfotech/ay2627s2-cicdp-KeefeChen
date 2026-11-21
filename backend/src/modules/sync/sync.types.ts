/**
 * File Name: sync.types.ts
 * Description: Types for the offline-first change feed.
 * Author: Keefe Chen
 */

export interface TaskChange {
  id: string;
  userId: string;
  title: string;
  description: string | null;
  course: string;
  tags: string[];
  groupId: string | null;
  assigneeId: string | null;
  assigneeName: string | null;
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

import type { CreateTaskInput, UpdateTaskInput } from "../tasks/task.types.js";

export type SyncOperationInput =
  | {
      opId: string;
      type: "task.create";
      payload: CreateTaskInput;
    }
  | {
      opId: string;
      type: "task.update";
      payload: UpdateTaskInput & { taskId: string };
    }
  | {
      opId: string;
      type: "task.delete";
      payload: { taskId: string };
    };

export interface SyncOperationResult {
  opId: string;
  type: SyncOperationInput["type"];
  status: "applied" | "failed" | "conflict";
  detail?: unknown;
  replayed: boolean;
}

export interface SyncPushResult {
  serverTime: Date;
  results: SyncOperationResult[];
}
