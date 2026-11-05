/**
 * File Name: sync.service.ts
 * Description: Business logic layer managing timestamp conflicts and change feeds.
 * Author: Keefe Chen
 */

import { ISyncRepository } from './sync.repository';
import { SyncChangesResult, TaskChange } from './sync.types';

export class SyncService {
  constructor(private readonly syncRepository: ISyncRepository) {}

  public async getChangesSince(userId: string, since: Date): Promise<SyncChangesResult> {
    const serverTime = new Date();
    const tasks = await this.syncRepository.fetchChangesSince(userId, since);

    return {
      serverTime,
      since,
      tasks,
    };
  }

  public async pushChanges(userId: string, changes: Partial<TaskChange>[]): Promise<SyncChangesResult> {
    const serverTime = new Date();

    if (changes.length > 0) {
      await this.syncRepository.applyTaskChanges(userId, changes);
    }

    const tasks = await this.syncRepository.fetchChangesSince(userId, new Date(0));

    return {
      serverTime,
      since: new Date(0),
      tasks,
    };
  }
}