/**
 * File Name: session.validation.ts
 * Description: Zod schemas for group study session requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

import { SESSION_STATUSES } from "./session.types.js";

const nullableDate = z.union([z.coerce.date(), z.null()]);

/**
 * POST /api/groups/:groupId/sessions
 */
export const createSessionSchema = z.object({
  body: z
    .object({
      title: z
        .string()
        .trim()
        .min(1, "Session title is required.")
        .max(150, "Session titles cannot exceed 150 characters."),

      description: z
        .string()
        .trim()
        .max(2000)
        .nullable()
        .optional(),

      startsAt: z.coerce.date(),

      endsAt: z.coerce.date(),

      location: z
        .string()
        .trim()
        .max(200)
        .nullable()
        .optional(),

      maxAttendees: z.coerce
        .number()
        .int()
        .min(1)
        .max(200)
        .nullable()
        .optional(),
    })
    .strict()
    .refine((body) => body.endsAt > body.startsAt, {
      message: "endsAt must be later than startsAt.",
      path: ["endsAt"],
    }),
});

/**
 * GET /api/groups/:groupId/sessions
 */
export const listSessionsSchema = z.object({
  query: z
    .object({
      page: z.coerce.number().int().min(1).default(1),

      limit: z.coerce.number().int().min(1).max(100).default(20),

      status: z.enum(SESSION_STATUSES).optional(),

      from: z.coerce.date().optional(),

      to: z.coerce.date().optional(),
    })
    .strict(),
});

/**
 * GET, PATCH and DELETE /api/groups/:groupId/sessions/:sessionId
 */
export const sessionParamSchema = z.object({
  params: z.object({
    groupId: z.string().trim().min(1),
    sessionId: z.string().trim().min(1),
  }),
});

/**
 * PATCH /api/groups/:groupId/sessions/:sessionId
 */
export const updateSessionSchema = z.object({
  params: sessionParamSchema.shape.params,

  body: z
    .object({
      title: z.string().trim().min(1).max(150).optional(),

      description: z
        .string()
        .trim()
        .max(2000)
        .nullable()
        .optional(),

      startsAt: z.coerce.date().optional(),

      endsAt: z.coerce.date().optional(),

      location: z
        .string()
        .trim()
        .max(200)
        .nullable()
        .optional(),
    })
    .strict()
    .refine((body) => Object.keys(body).length > 0, {
      message: "At least one field must be provided.",
    }),
});
