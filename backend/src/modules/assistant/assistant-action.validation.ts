/**
 * File Name: assistant-action.validation.ts
 * Description: Zod schemas for the AI action-execution endpoints.
 */

import { z } from "zod";

const conversationTurn = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().max(4000),
});

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** A structured pre-parsed action from the UI; re-validated server-side. */
const structuredAction = z
  .object({
    type: z.string().trim().min(1).max(60),
    params: z.record(z.string(), z.unknown()).optional(),
  })
  .strict();

export const actSchema = z.object({
  body: z
    .object({
      message: z.string().trim().min(1, "Message is required.").max(4000).optional(),
      context: z.array(conversationTurn).max(50).optional(),
      currentDate: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .optional(),
      utcOffsetMinutes: z.number().int().min(-840).max(840).optional(),
      /** Idempotency key; repeated submissions cannot create duplicates. */
      clientRequestId: z.string().regex(UUID_RE, "Invalid request ID.").optional(),
      action: structuredAction.optional(),
    })
    .strict()
    .refine((b) => b.message !== undefined || b.action !== undefined, {
      message: "Either message or action is required.",
    }),
});

export const pendingActionSchema = z.object({
  body: z
    .object({
      pendingActionId: z.string().trim().min(1, "pendingActionId is required."),
    })
    .strict(),
});

export type ActBody = z.infer<typeof actSchema>["body"];
