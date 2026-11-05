/**
 * File Name: sync.repository.ts
 * Description: Data access abstraction layer for fetching and writing sync deltas.
 * Author: Keefe Chen
 */

import { TaskChange } from './sync.types';
import { TaskChangeModel } from './sync.model';

export interface ISyncRepository {
  fetchChangesSince(userId: string, since: Date): Promise<TaskChange[]>;
  applyTaskChanges(userId: string, changes: Partial<TaskChange>[]): Promise<TaskChange[]>;
}

export class SyncRepository implements ISyncRepository {
  // In-memory data store for demonstration (Swap with Prisma, TypeORM, SQL query runner, etc.)
  private readonly store: Map<string, TaskChangeModel> = new Map();

  async fetchChangesSince(userId: string, since: Date): Promise<TaskChange[]> {
    const results: TaskChange[] = [];

    for (const record of this.store.values()) {
      if (record.userId === userId && record.updatedAt > since) {
        results.push(record);
      }
    }

    return results.sort((a, b) => a.updatedAt.getTime() - b.updatedAt.getTime());
  }

  async applyTaskChanges(userId: string, changes: Partial<TaskChange>[]): Promise<TaskChange[]> {
    const updatedRecords: TaskChange[] = [];
    const now = new Date();

    for (const change of changes) {
      if (!change.id) continue;

      const existing = this.store.get(change.id);
      const updatedEntity = new TaskChangeModel({
        ...existing,
        ...change,
        userId,
        updatedAt: now,
        createdAt: existing?.createdAt ?? change.createdAt ?? now,
      });

      this.store.set(change.id, updatedEntity);
      updatedRecords.push(updatedEntity);
    }

    return updatedRecords;
  }
}