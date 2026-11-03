/**
 * File Name: batch.validation.ts
 * Description: Zod schemas for bulk membership requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

export const MAX_BATCH_SIZE = 500;

/**
 * Group member identifiers. The backend supports both UUID-based user
 * documents (users module) and ObjectId-based documents (auth module).
 */
const memberIdSchema = z
  .string()
  .trim()
  .min(1, "Member IDs cannot be empty.")
  .max(64, "Member IDs cannot exceed 64 characters.");

/**
 * POST /api/groups/:groupId/members/batch
 */
export const batchAddMembersSchema = z.object({
  body: z
    .object({
      memberIds: z
        .array(memberIdSchema)
        .min(1, "At least one member ID is required.")
        .max(
          MAX_BATCH_SIZE,
          `Batch size cannot exceed ${MAX_BATCH_SIZE} members.`,
        ),

      atomic: z.boolean().optional(),
    })
    .strict(),
});
