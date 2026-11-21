/**
 * File Name: assistant.validation.ts
 * Description: Zod schemas for the assistant endpoints.
 */

import { z } from "zod";

const conversationTurn = z.object({
  role: z.enum(["user", "assistant"]),
  content: z.string().max(4000),
});

const context = z.array(conversationTurn).max(50).optional();

export const interpretSchema = z.object({
  body: z
    .object({
      message: z.string().trim().min(1, "Message is required.").max(4000),
      context,
      currentDate: z.string().max(40).optional(),
      utcOffsetMinutes: z.number().int().min(-720).max(840).optional(),
    })
    .strict(),
});

export const clarifySchema = z.object({
  body: z
    .object({
      draftId: z.string().min(1, "draftId is required."),
      message: z.string().trim().min(1, "Message is required.").max(4000),
    })
    .strict(),
});

export const draftParamSchema = z.object({
  body: z
    .object({
      draftId: z.string().min(1, "draftId is required."),
    })
    .strict(),
});

const draftEdits = z
  .object({
    title: z.string().trim().min(1).max(150).optional(),
    description: z.string().trim().max(5000).nullable().optional(),
    course: z.string().trim().max(120).optional(),
    dueDate: z.coerce.date().nullable().optional(),
    priority: z.enum(["low", "medium", "high", "urgent"]).nullable().optional(),
    tags: z.array(z.string().trim().min(1).max(24)).max(8).optional(),
  })
  .strict();

export const previewSchema = z.object({
  body: z
    .object({
      draftId: z.string().min(1, "draftId is required."),
      edits: draftEdits.optional(),
    })
    .strict(),
});

export const confirmSchema = z.object({
  body: z
    .object({
      draftId: z.string().min(1, "draftId is required."),
      edits: draftEdits.optional(),
    })
    .strict(),
});

export const cancelSchema = z.object({
  body: z
    .object({
      draftId: z.string().min(1, "draftId is required."),
    })
    .strict(),
});

export const suggestionsSchema = z.object({
  body: z
    .object({
      course: z.string().trim().max(120).optional(),
    })
    .strict()
    .optional(),
});

export type DraftEdits = z.infer<typeof draftEdits>;
