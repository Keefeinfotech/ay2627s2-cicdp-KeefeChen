/**
 * File Name: rubric.validation.ts
 * Description: Zod schemas for group rubric requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

/**
 * POST /api/groups/:groupId/rubrics/parse
 */
export const parseRubricSchema = z.object({
  body: z
    .object({
      title: z
        .string()
        .trim()
        .min(1, "A rubric title is required.")
        .max(200, "Rubric titles cannot exceed 200 characters."),

      sourceText: z
        .string()
        .trim()
        .min(1, "Rubric text is required.")
        .max(30000, "Rubric text cannot exceed 30000 characters."),
    })
    .strict(),
});

/**
 * GET /api/groups/:groupId/rubrics
 */
export const listRubricsSchema = z.object({
  query: z
    .object({
      page: z.coerce.number().int().min(1).default(1),

      limit: z.coerce
        .number()
        .int()
        .min(1)
        .max(100)
        .default(20),
    })
    .strict(),
});

/**
 * GET /api/groups/:groupId/rubrics/:rubricId
 * DELETE /api/groups/:groupId/rubrics/:rubricId
 */
export const rubricParamSchema = z.object({
  params: z.object({
    groupId: z.string().trim().min(1),
    rubricId: z.string().trim().min(1),
  }),
});

/**
 * POST /api/groups/:groupId/rubrics/:rubricId/roadmap-proposals
 */
export const rubricRoadmapProposalSchema = z.object({
  params: rubricParamSchema.shape.params,
});
