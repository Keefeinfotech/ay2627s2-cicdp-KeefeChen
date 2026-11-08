import { z } from "zod";

const dateOnlySchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((value) => {
    const parsed = new Date(`${value}T00:00:00.000Z`);
    return (
      Number.isFinite(parsed.getTime()) &&
      parsed.toISOString().slice(0, 10) === value
    );
  }, "Date must be a real calendar date.");

export const chatSchema = z.object({
  body: z
    .object({
      message: z
        .string()
        .trim()
        .min(1, "Message is required")
        .max(1000, "Message must be at most 1000 characters"),
      context: z
        .array(
          z
            .object({
              role: z.enum(["user", "assistant"]),
              content: z.string().trim().min(1).max(1000),
            })
            .strict(),
        )
        .max(10)
        .optional(),
    })
    .strict(),
});

export const taskDraftRequestSchema = z.object({
  body: z
    .object({
      message: z.string().trim().min(1).max(1000),
      context: z
        .array(
          z
            .object({
              role: z.enum(["user", "assistant"]),
              content: z.string().trim().min(1).max(1000),
            })
            .strict(),
        )
        .max(10)
        .optional(),
      currentDate: dateOnlySchema.optional(),
      utcOffsetMinutes: z.number().int().min(-840).max(840).optional(),
    })
    .strict(),
});

export const taskDraftResponseSchema = z
  .object({
    reply: z.string().trim().min(1).max(1000),
    draft: z
      .object({
        title: z.string().trim().min(1).max(150),
        description: z.string().trim().max(5000).nullable(),
        course: z.string().trim().max(120).nullable(),
        dueDate: dateOnlySchema.nullable(),
        priority: z.enum(["low", "medium", "high"]).nullable(),
      })
      .strict()
      .nullable(),
    clarification: z.string().trim().max(500).nullable(),
  })
  .strict();
