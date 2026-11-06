/**
 * File Name: sync.repository.ts
 * Description: MongoDB data access for the offline-first change feed.
 * Author: Keefe Chen
 */

import { Task } from "../tasks/task.model.js";
import type { TaskChange } from "./sync.types.js";

export interface ISyncRepository {
  fetchChangesSince(userId: string, since: Date): Promise<TaskChange[]>;
}

interface TaskChangeDocument {
  _id: string;
  userId: string;
  title: string;
  description: string | null;
  course: string;
  tags?: string[];
  groupId?: string | null;
  assigneeId?: string | null;
  assigneeName?: string | null;
  reminderAt: Date | null;
  status: string;
  priority: string;
  dueDate: Date | null;
  completedAt: Date | null;
  deletedAt?: Date | null;
  updatedAt: Date;
  createdAt: Date;
}

export class SyncRepository implements ISyncRepository {
  async fetchChangesSince(userId: string, since: Date): Promise<TaskChange[]> {
    const documents = await Task.find({
      $or: [{ userId }, { assigneeId: userId }],
      updatedAt: { $gt: since },
    })
      .select("+deletedAt")
      .lean<TaskChangeDocument[]>()
      .exec();

    return documents.map((document) => ({
      id: document._id,
      userId: document.userId,
      title: document.title,
      description: document.description,
      course: document.course,
      tags: document.tags ?? [],
      groupId: document.groupId ?? null,
      assigneeId: document.assigneeId ?? null,
      assigneeName: document.assigneeName ?? null,
      reminderAt: document.reminderAt,
      status: document.status,
      priority: document.priority,
      dueDate: document.dueDate,
      completedAt: document.completedAt,
      deletedAt: document.deletedAt ?? null,
      updatedAt: document.updatedAt,
      createdAt: document.createdAt,
    }));
  }
}
