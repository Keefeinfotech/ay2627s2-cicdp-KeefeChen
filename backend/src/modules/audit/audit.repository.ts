/**
 * File Name: audit.repository.ts
 * Description: Persists and retrieves group activity events.
 * Author: Keefe Chen
 */

import { AuditEvent } from "./audit.model.js";

import type { AuditEventRecord } from "./audit.model.js";
import type { AuditListResult, RecordAuditInput } from "./audit.types.js";

export const auditRepository = {
  async create(input: RecordAuditInput): Promise<AuditEventRecord> {
    const event = await AuditEvent.create({
      groupId: input.groupId,
      actorId: input.actorId,
      action: input.action,
      targetType: input.targetType ?? null,
      targetId: input.targetId ?? null,
      metadata: input.metadata ?? null,
    });

    return event.toObject() as AuditEventRecord;
  },

  async listByGroup(
    groupId: string,
    page: number,
    limit: number,
    action?: string,
  ): Promise<AuditListResult<AuditEventRecord>> {
    const filter: Record<string, unknown> = { groupId };

    if (action) {
      filter.action = action;
    }

    const skip = (page - 1) * limit;

    const [items, totalItems] = await Promise.all([
      AuditEvent.find(filter)
        .sort({ createdAt: -1, _id: -1 })
        .skip(skip)
        .limit(limit)
        .lean<AuditEventRecord[]>()
        .exec(),
      AuditEvent.countDocuments(filter).exec(),
    ]);

    const totalPages = Math.ceil(totalItems / limit);

    return {
      items,
      pagination: {
        page,
        limit,
        totalItems,
        totalPages,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
      },
    };
  },
};
