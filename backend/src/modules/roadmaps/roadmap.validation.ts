/**
 * File Name: roadmap.validation.ts
 * Description: Zod schemas for group roadmap requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

import {
  ROADMAP_ITEM_STATUSES,
  ROADMAP_STATUSES,
} from "./roadmap.types.js";

const roadmapItemSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(1, "Roadmap item title is required.")
      .max(150, "Roadmap item titles cannot exceed 150 characters."),

    description: z
      .string()
      .trim()
      .max(2000, "Descriptions cannot exceed 2000 characters.")
      .nullable()
      .optional(),

    criterion: z
      .string()
      .trim()
      .max(200)
      .nullable()
      .optional(),

    weight: z
      .number()
      .min(0)
      .max(100)
      .nullable()
      .optional(),

    estimateHours: z
      .number()
      .min(0)
      .max(1000)
      .nullable()
      .optional(),

    status: z.enum(ROADMAP_ITEM_STATUSES).optional(),
  })
  .strict();

const listQuerySchema = z.object({
  query: z
    .object({
      page: z.coerce.number().int().min(1).default(1),

      limit: z.coerce
        .number()
        .int()
        .min(1)
        .max(100)
        .default(20),

      status: z.enum(ROADMAP_STATUSES).optional(),
    })
    .strict(),
});

/**
 * POST /api/groups/:groupId/roadmap
 */
export const createRoadmapSchema = z.object({
  body: z
    .object({
      title: z
        .string()
        .trim()
        .min(1, "Roadmap title is required.")
        .max(200, "Roadmap titles cannot exceed 200 characters."),

      description: z
        .string()
        .trim()
        .max(2000, "Descriptions cannot exceed 2000 characters.")
        .nullable()
        .optional(),

      items: z.array(roadmapItemSchema).max(500).optional(),
    })
    .strict(),
});

/**
 * GET /api/groups/:groupId/roadmap
 */
export const listRoadmapsSchema = listQuerySchema;

/**
 * GET, PATCH and DELETE /api/groups/:groupId/roadmap/:roadmapId
 */
export const roadmapParamSchema = z.object({
  params: z.object({
    groupId: z.string().trim().min(1),
    roadmapId: z.string().trim().min(1),
  }),
});

/**
 * PATCH /api/groups/:groupId/roadmap/:roadmapId
 */
export const updateRoadmapSchema = z.object({
  params: roadmapParamSchema.shape.params,

  body: z
    .object({
      title: z.string().trim().min(1).max(200).optional(),

      description: z
        .string()
        .trim()
        .max(2000)
        .nullable()
        .optional(),

      status: z.enum(ROADMAP_STATUSES).optional(),
    })
    .strict()
    .refine((body) => Object.keys(body).length > 0, {
      message: "At least one field must be provided.",
    }),
});

/**
 * POST /api/groups/:groupId/roadmap/:roadmapId/approve
 */
export const approveRoadmapSchema = z.object({
  params: roadmapParamSchema.shape.params,
});

/**
 * PATCH /api/groups/:groupId/roadmap/:roadmapId/items/:itemId
 */
export const updateRoadmapItemSchema = z.object({
  params: z
    .object({
      groupId: z.string().trim().min(1),
      roadmapId: z.string().trim().min(1),
      itemId: z.string().trim().min(1),
    }),

  body: z
    .object({
      status: z.enum(ROADMAP_ITEM_STATUSES).optional(),

      title: z.string().trim().min(1).max(150).optional(),

      estimateHours: z
        .number()
        .min(0)
        .max(1000)
        .nullable()
        .optional(),
    })
    .strict()
    .refine((body) => Object.keys(body).length > 0, {
      message: "At least one field must be provided.",
    }),
});
