/**
 * File Name: sync.service.ts
 * Description: Business logic for the offline-first change feed.
 * Author: Keefe Chen
 */

import type { ISyncRepository } from "./sync.repository.js";
import type { SyncChangesResult } from "./sync.types.js";

export class SyncService {
  constructor(private readonly syncRepository: ISyncRepository) {}

  /**
   * Returns tasks updated since the supplied timestamp, including soft-deleted
   * records so clients can reconcile deletions.
   */
  async getChangesSince(
    userId: string,
    since: Date,
  ): Promise<SyncChangesResult> {
    const tasks = await this.syncRepository.fetchChangesSince(userId, since);

    return {
      serverTime: new Date(),
      since,
      tasks,
    };
  }
}
