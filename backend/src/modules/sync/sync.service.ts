/**
 * File Name: sync.service.ts
 * Description: Business logic for the offline-first change feed.
 * Author: Keefe Chen
 */

import type { ISyncRepository } from "./sync.repository.js";
import { SyncOperation } from "./sync-operation.model.js";
import { taskService } from "../tasks/task.service.js";
import { AppError } from "../../shared/utils/AppError.js";

import type {
  SyncChangesResult,
  SyncOperationInput,
  SyncOperationResult,
  SyncPushResult,
} from "./sync.types.js";

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

  /**
   * Applies a batch of client operations with idempotency: an opId that was
   * already processed returns the stored result instead of re-applying.
   * Conflicts are reported per operation, never silently overwritten.
   */
  async push(
    userId: string,
    operations: SyncOperationInput[],
  ): Promise<SyncPushResult> {
    const results: SyncOperationResult[] = [];

    for (const operation of operations) {
      const existing = await SyncOperation.findOne({
        userId,
        opId: operation.opId,
      }).lean();

      if (existing) {
        results.push({
          opId: operation.opId,
          type: operation.type,
          status: existing.status,
          detail: existing.detail,
          replayed: true,
        });
        continue;
      }

      const result = await this.applyOperation(userId, operation);

      try {
        await SyncOperation.create({
          userId,
          opId: operation.opId,
          type: operation.type,
          status: result.status,
          detail: result.detail ?? null,
        });
      } catch (error) {
        // Unique-index race: another replica stored the same op first. The
        // stored result wins; treat this operation as a replay.
        if (
          typeof error === "object" &&
          error !== null &&
          "code" in error &&
          (error as { code?: number }).code === 11000
        ) {
          const stored = await SyncOperation.findOne({
            userId,
            opId: operation.opId,
          }).lean();
          if (stored) {
            results.push({
              opId: operation.opId,
              type: operation.type,
              status: stored.status,
              detail: stored.detail,
              replayed: true,
            });
            continue;
          }
        }
        throw error;
      }

      results.push({
        ...result,
        opId: operation.opId,
        type: operation.type,
        replayed: false,
      });
    }

    return { serverTime: new Date(), results };
  }

  private async applyOperation(
    userId: string,
    operation: SyncOperationInput,
  ): Promise<Omit<SyncOperationResult, "replayed" | "opId" | "type">> {
    try {
      switch (operation.type) {
        case "task.create": {
          const task = await taskService.createTask(userId, operation.payload);
          return { status: "applied", detail: { taskId: String(task._id) } };
        }
        case "task.update": {
          const { taskId, ...input } = operation.payload;
          const task = await taskService.updateTask(userId, taskId, input);
          return {
            status: "applied",
            detail: { taskId: String(task._id), updatedAt: task.updatedAt },
          };
        }
        case "task.delete": {
          await taskService.deleteTask(userId, operation.payload.taskId);
          return {
            status: "applied",
            detail: { taskId: operation.payload.taskId },
          };
        }
      }
    } catch (error) {
      if (error instanceof AppError && error.code === "TASK_CONFLICT") {
        return { status: "conflict", detail: { code: error.code } };
      }
      if (error instanceof AppError && error.status === 404) {
        return { status: "failed", detail: { code: error.code } };
      }
      throw error;
    }
  }

  /**
   * Resolves a client/server conflict. 'server' returns the authoritative
   * state; 'client' applies the supplied client state (without a CAS
   * precondition) and returns the merged record.
   */
  async resolveConflict(
    userId: string,
    input: {
      taskId: string;
      resolution: "client" | "server";
      clientState?: {
        title?: string;
        description?: string | null;
        course?: string;
        tags?: string[];
        priority?: "low" | "medium" | "high" | "urgent";
        status?: "todo" | "in_progress" | "completed" | "archived";
        dueDate?: Date | null;
        reminderAt?: Date | null;
      };
    },
  ) {
    if (input.resolution === "server") {
      return taskService.getTask(userId, input.taskId);
    }

    return taskService.updateTask(
      userId,
      input.taskId,
      input.clientState ?? {},
    );
  }

  /** Server-reported sync status for client diagnostics. */
  async getStatus(userId: string) {
    void userId; // reserved for per-user counters later
    return {
      serverTime: new Date(),
      supportedOperations: ["task.create", "task.update", "task.delete"],
      protocol: 1,
    };
  }
}
