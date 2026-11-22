/**
 * File Name: reminder.validation.ts
 * Description: Zod schemas for reminder endpoints.
 */

import { z } from "zod";

import { REMINDER_RECURRENCES } from "./reminder.model.js";

export const createReminderSchema = z.object({
  body: z
    .object({
      message: z.string().trim().min(1, "Message is required.").max(500),
      dueAt: z.coerce.date(),
      taskId: z.string().uuid().nullish(),
      recurrence: z.enum(REMINDER_RECURRENCES).optional(),
      enabled: z.boolean().optional(),
    })
    .strict(),
});

export const updateReminderSchema = z.object({
  params: z.object({ reminderId: z.string().min(1) }),
  body: z
    .object({
      message: z.string().trim().min(1).max(500).optional(),
      dueAt: z.coerce.date().optional(),
      taskId: z.string().uuid().nullish(),
      recurrence: z.enum(REMINDER_RECURRENCES).optional(),
      enabled: z.boolean().optional(),
      completed: z.boolean().optional(),
    })
    .strict()
    .refine((b) => Object.keys(b).length > 0, {
      message: "At least one field must be provided.",
    }),
});

export const reminderIdParamSchema = z.object({
  params: z.object({ reminderId: z.string().min(1) }),
});

export const upcomingRemindersSchema = z.object({
  query: z.object({
    days: z.coerce.number().int().min(1).max(90).default(7),
  }),
});

export const taskReminderParamsSchema = z.object({
  params: z.object({ taskId: z.string().uuid("Invalid task ID.") }),
});

export const createTaskReminderSchema = z.object({
  params: z.object({ taskId: z.string().uuid("Invalid task ID.") }),
  body: z
    .object({
      message: z.string().trim().min(1, "Message is required.").max(500),
      dueAt: z.coerce.date(),
      recurrence: z.enum(REMINDER_RECURRENCES).optional(),
      enabled: z.boolean().optional(),
    })
    .strict(),
});

export const reminderStatusSchema = z.object({
  params: z.object({ reminderId: z.string().min(1) }),
  body: z
    .object({
      completed: z.boolean().optional(),
      enabled: z.boolean().optional(),
    })
    .strict()
    .refine(
      (b) => typeof b.completed === "boolean" || typeof b.enabled === "boolean",
      {
        message: "Provide 'completed' or 'enabled'.",
      },
    ),
});
