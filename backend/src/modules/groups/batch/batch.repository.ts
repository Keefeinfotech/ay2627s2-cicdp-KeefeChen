/**
 * File Name: batch.repository.ts
 * Description: Enterprise data access layer for atomic and resilient batch operations.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";
import { GroupMemberModel } from "../core/group.model.js";
import {
  BatchJob,
  BatchJobStatus,
  BatchOperationType,
  type BatchItemError,
  type BatchJobRecord,
} from "./batch.model.js";
import type { BatchAtomicResult, BatchProcessResult } from "./batch.types.js";

export const BatchRepository = {
  CHUNK_SIZE: 100,

  /**
   * Atomic Execution: Uses Mongoose ACID Transactions.
   */
  async addMembersAtomic(
    groupId: string,
    memberIds: string[]
  ): Promise<BatchAtomicResult> {
    const session = await mongoose.startSession();
    session.startTransaction();

    try {
      const docs = memberIds.map((userId) => ({ groupId, userId }));
      const insertedDocs = await GroupMemberModel.insertMany(docs, {
        session,
        ordered: true,
      });

      await session.commitTransaction();

      return {
        count: insertedDocs.length,
      };
    } catch (error) {
      await session.abortTransaction();
      throw error;
    } finally {
      await session.endSession();
    }
  },

  /**
   * Resilient Execution: Performs chunked bulkWrite operations to capture per-item errors.
   */
  async addMembersPartial(
    groupId: string,
    memberIds: string[]
  ): Promise<BatchProcessResult> {
    const successful: string[] = [];
    const failed: BatchItemError[] = [];

    for (let i = 0; i < memberIds.length; i += this.CHUNK_SIZE) {
      const chunk = memberIds.slice(i, i + this.CHUNK_SIZE);
      const bulkOps = chunk.map((userId) => ({
        insertOne: { document: { groupId, userId } },
      }));

      try {
        await GroupMemberModel.bulkWrite(bulkOps, { ordered: false });
        chunk.forEach((userId) => successful.push(userId));
      } catch (error: any) {
        if (error.name === "MongoBulkWriteError" && Array.isArray(error.writeErrors)) {
          const failedIndices = new Set(error.writeErrors.map((e: any) => e.index));

          chunk.forEach((userId, chunkIdx) => {
            const globalIdx = i + chunkIdx;
            if (failedIndices.has(chunkIdx)) {
              const writeErr = error.writeErrors.find((e: any) => e.index === chunkIdx);
              failed.push({
                index: globalIdx,
                memberId: userId,
                code: writeErr?.code === 11000 ? "DUPLICATE_ENTRY" : "INSERT_FAILED",
                message: writeErr?.errmsg || "Failed to insert member into group",
              });
            } else {
              successful.push(userId);
            }
          });
        } else {
          chunk.forEach((userId, chunkIdx) => {
            failed.push({
              index: i + chunkIdx,
              memberId: userId,
              code: "BATCH_ERROR",
              message: error.message || "Unknown write error",
            });
          });
        }
      }
    }

    return {
      successful,
      failed,
      totalProcessed: memberIds.length,
    };
  },

  /**
   * Persists job audit logs using your `BatchJob` Mongoose model.
   */
  async recordJob(payload: {
    groupId: string;
    requestedBy: string;
    totalCount: number;
    successCount: number;
    failureCount: number;
    errors: BatchItemError[];
  }): Promise<BatchJobRecord> {
    let status: BatchJobStatus = BatchJobStatus.COMPLETED;
    if (payload.failureCount > 0) {
      status =
        payload.successCount > 0
          ? BatchJobStatus.PARTIALLY_FAILED
          : BatchJobStatus.FAILED;
    }

    const job = await BatchJob.create({
      ...payload,
      operationType: BatchOperationType.ADD_MEMBERS,
      status,
    });

    return job.toObject();
  },
};