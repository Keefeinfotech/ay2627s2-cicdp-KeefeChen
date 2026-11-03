/**
 * File Name: audit.service.ts
 * Description: Records group activity and serves the activity trail.
 * Author: Keefe Chen
 */

import logger from "../../config/logger.js";
import { requireGroupMembership } from "../groups/shared/membership.js";
import { auditRepository } from "./audit.repository.js";

import type {
  AuditListResult,
  ListAuditQuery,
  RecordAuditInput,
} from "./audit.types.js";
import type { AuditEventRecord } from "./audit.model.js";

export const auditService = {
  /**
   * Records an activity event.
   *
   * Auditing must never break the operation it describes, so failures are
   * logged instead of propagated.
   */
  async record(input: RecordAuditInput): Promise<void> {
    try {
      await auditRepository.create(input);
    } catch (error) {
      logger.error("Failed to record audit event", {
        groupId: input.groupId,
        action: input.action,
        error: error instanceof Error ? error.message : "Unknown error",
      });
    }
  },

  /**
   * Lists the activity trail for an active group member.
   */
  async list(
    groupId: string,
    userId: string,
    query: ListAuditQuery,
  ): Promise<AuditListResult<AuditEventRecord>> {
    await requireGroupMembership(groupId, userId);

    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    return auditRepository.listByGroup(groupId, page, limit, query.action);
  },
};
