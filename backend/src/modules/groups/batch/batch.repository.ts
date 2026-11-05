/**
 * File Name: batch.repository.ts
 * Description: Persists bulk group membership changes and their audit records.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import { Member } from "../member/member.model.js";
import {
  BatchJob,
  BatchJobStatus,
  BatchOperationType,
} from "./batch.model.js";

import type {
  BatchAtomicResult,
  BatchItemError,
  BatchProcessResult,
} from "./batch.types.js";

import type { BatchJobRecord } from "./batch.model.js";

const CHUNK_SIZE = 100;

/**
 * Reactivates an existing membership instead of creating a duplicate.
 * The unique (groupId, userId) index makes this operation idempotent.
 */
const membershipUpsert = (groupId: string, userId: string) => ({
  updateOne: {
    filter: { groupId, userId },
    update: {
      $set: { status: "ACTIVE" },
      $setOnInsert: { role: "MEMBER" },
    },
    upsert: true,
  },
});

interface WriteErrorShape {
  index?: number;
  code?: number | string;
  errmsg?: string;
  message?: string;
}

const writeErrorsOf = (error: unknown): WriteErrorShape[] => {
  if (typeof error !== "object" || error === null) {
    return [];
  }

  const candidate = error as {
    writeErrors?: WriteErrorShape[];
    result?: { writeErrors?: WriteErrorShape[] };
  };

  return candidate.writeErrors ?? candidate.result?.writeErrors ?? [];
};

export const batchRepository = {
  /**
   * Applies every membership change inside one MongoDB transaction.
   */
  async addMembersAtomic(
    groupId: string,
    memberIds: string[],
  ): Promise<BatchAtomicResult> {
    const session = await mongoose.startSession();

    try {
      let count = 0;

      await session.withTransaction(async () => {
        const result = await Member.bulkWrite(
          memberIds.map((userId) => membershipUpsert(groupId, userId)),
          { session, ordered: true },
        );

        count = result.upsertedCount + result.modifiedCount;
      });

      return { count };
    } finally {
      await session.endSession();
    }
  },

  /**
   * Applies membership changes in chunks and reports item-level failures.
   */
  async addMembersPartial(
    groupId: string,
    memberIds: string[],
  ): Promise<BatchProcessResult> {
    const successful: string[] = [];
    const failed: BatchItemError[] = [];

    for (let start = 0; start < memberIds.length; start += CHUNK_SIZE) {
      const chunk = memberIds.slice(start, start + CHUNK_SIZE);
      const failures = new Map<number, BatchItemError>();

      try {
        await Member.bulkWrite(
          chunk.map((userId) => membershipUpsert(groupId, userId)),
          { ordered: false },
        );
      } catch (error) {
        for (const writeError of writeErrorsOf(error)) {
          const index = Number(writeError.index);
          if (!Number.isInteger(index) || index < 0 || index >= chunk.length) {
            continue;
          }

          failures.set(index, {
            index: start + index,
            id: chunk[index],
            code: String(writeError.code ?? "INSERT_FAILED"),
            message:
              writeError.errmsg ??
              writeError.message ??
              "Failed to add member.",
          });
        }
      }

      chunk.forEach((userId, index) => {
        const failure = failures.get(index);
        if (failure) {
          failed.push(failure);
        } else {
          successful.push(userId);
        }
      });
    }

    return {
      successful,
      failed,
      totalProcessed: memberIds.length,
    };
  },

  /**
   * Persists a completed batch job for auditing and retries.
   */
  async recordJob(input: {
    groupId: string;
    requestedBy: string;
    totalCount: number;
    successCount: number;
    failureCount: number;
    errors: BatchItemError[];
  }): Promise<BatchJobRecord> {
    const status =
      input.failureCount === 0
        ? BatchJobStatus.COMPLETED
        : input.successCount === 0
          ? BatchJobStatus.FAILED
          : BatchJobStatus.PARTIALLY_FAILED;

    const job = await BatchJob.create({
      ...input,
      operationType: BatchOperationType.ADD_MEMBERS,
      status,
    });

    return job.toObject() as BatchJobRecord;
  },
};
