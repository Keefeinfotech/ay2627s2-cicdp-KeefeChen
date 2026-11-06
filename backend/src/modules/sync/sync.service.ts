/**
 * File Name: sync.service.ts
 * Description: Builds a change feed for offline-first clients.
 * Author: Keefe Chen
 */

import { Task } from "../tasks/task.model.js";

import type { SyncChangesResult, TaskChange } from "./sync.types.js";

export const syncService = {
  /**
   * Returns tasks updated since the supplied timestamp, including soft-deleted
   * records so clients can reconcile deletions.
   */
  async getChanges(
    userId: string,
    since: Date | null,
  ): Promise<SyncChangesResult> {
    const sinceDate = since ?? new Date(0);

    const documents = await Task.find({
      $or: [{ userId }, { assigneeId: userId }],
      updatedAt: { $gt: sinceDate },
    })
      .select("+deletedAt")
      .lean<
        {
          _id: string;
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
          createdAt: Date;
          updatedAt: Date;
        }[]
      >()
      .exec();

    const tasks: TaskChange[] = documents.map((document) => ({
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
      deletedAt: document.deletedAt,
      createdAt: document.createdAt,
      updatedAt: document.updatedAt,
    }));

    return {
      serverTime: new Date(),
      since: sinceDate,
      tasks,
    };
  },
};
