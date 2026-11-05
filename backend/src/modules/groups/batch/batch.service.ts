/**
 * File Name: batch.service.ts
 * Description: Business rules for bulk group membership changes.
 * Author: Keefe Chen
 */

import mongoose from "mongoose";

import {
  GROUP_MANAGER_ROLES,
  requireGroupRole,
} from "../shared/membership.js";
import { auditService } from "../../audit/audit.service.js";
import { AUDIT_ACTIONS } from "../../audit/audit.types.js";
import { batchRepository } from "./batch.repository.js";

import type {
  BatchAddMembersInput,
  BatchAtomicResult,
  BatchProcessResult,
} from "./batch.types.js";

import type { BatchJobRecord } from "./batch.model.js";

export const batchService = {
  /**
   * Adds multiple members to a group in one request.
   *
   * Only group owners and admins may perform bulk changes. The response is
   * either per-item results (resilient) or a transactional count (atomic).
   */
  async addMembers(
    groupId: string,
    requesterId: string,
    input: BatchAddMembersInput,
  ): Promise<
    | { mode: "atomic"; result: BatchAtomicResult; job: BatchJobRecord }
    | {
        mode: "partial";
        result: BatchProcessResult;
        job: BatchJobRecord;
      }
  > {
    await requireGroupRole(
      groupId,
      requesterId,
      GROUP_MANAGER_ROLES,
    );

    const memberIds = Array.from(new Set(input.memberIds)) as string[];

    const atomic = input.atomic === true;

    if (atomic) {
      // Atomic execution is an all-or-nothing transaction: a failure aborts
      // every change, so partial results are never recorded.
      try {
        const result = await batchRepository.addMembersAtomic(
          groupId,
          memberIds,
        );

        const job = await batchRepository.recordJob({
          groupId,
          requestedBy: requesterId,
          totalCount: memberIds.length,
          successCount: result.count,
          failureCount: 0,
          errors: [],
        });

        await auditService.record({
          groupId,
          actorId: requesterId,
          action: AUDIT_ACTIONS.MEMBERS_ADDED,
          targetType: "batch",
          targetId: job.jobId ?? null,
          metadata: { mode: "atomic", memberIds },
        });

        return { mode: "atomic", result, job };
      } catch (error) {
        await batchRepository.recordJob({
          groupId,
          requestedBy: requesterId,
          totalCount: memberIds.length,
          successCount: 0,
          failureCount: memberIds.length,
          errors: [
            {
              index: -1,
              code: "ATOMIC_BATCH_FAILED",
              message:
                error instanceof Error && error.message
                  ? error.message
                  : "The batch transaction failed.",
            },
          ],
        });

        throw error;
      }
    }

    const result = await batchRepository.addMembersPartial(
      groupId,
      memberIds,
    );

    const job = await batchRepository.recordJob({
      groupId,
      requestedBy: requesterId,
      totalCount: result.totalProcessed,
      successCount: result.successful.length,
      failureCount: result.failed.length,
      errors: result.failed,
    });

    await auditService.record({
      groupId,
      actorId: requesterId,
      action: AUDIT_ACTIONS.MEMBERS_ADDED,
      targetType: "batch",
      targetId: job.jobId ?? null,
      metadata: {
        mode: "partial",
        memberIds,
        failures: result.failed.map((failure) => failure.code),
      },
    });

    return { mode: "partial", result, job };
  },
};
