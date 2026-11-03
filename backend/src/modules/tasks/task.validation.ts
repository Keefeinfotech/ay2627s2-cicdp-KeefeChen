/**
 * File Name: task.validation.ts
 * Description: Defines Zod schemas for task API requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

import {
  TASK_PRIORITIES,
  TASK_STATUSES,
} from "./task.types.js";

/**
 * Accepts either a valid date or null.
 */
const nullableDate = z.union([
  z.coerce.date(),
  z.null(),
]);

/**
 * POST /api/tasks
 */
export const createTaskSchema = z.object({
  body: z
    .object({
      id: z.string().uuid().optional(),

      title: z
        .string()
        .trim()
        .min(1, "Task title is required.")
        .max(150, "Task title cannot exceed 150 characters."),

      description: z
        .string()
        .trim()
        .max(5000, "Description cannot exceed 5000 characters.")
        .nullable()
        .optional(),

      course: z
        .string()
        .trim()
        .max(120, "Course cannot exceed 120 characters.")
        .optional(),

      reminderAt: nullableDate.optional(),

      priority: z
        .enum(TASK_PRIORITIES)
        .optional(),

      dueDate: nullableDate.optional(),
    })
    .strict(),
});

/**
 * PATCH /api/tasks/:taskId
 */
export const updateTaskSchema = z.object({
  params: z.object({
    taskId: z.string().uuid("Invalid task ID."),
  }),

  body: z
    .object({
      title: z
        .string()
        .trim()
        .min(1)
        .max(150)
        .optional(),

      description: z
        .string()
        .trim()
        .max(5000)
        .nullable()
        .optional(),

      course: z
        .string()
        .trim()
        .max(120)
        .optional(),

      reminderAt: nullableDate.optional(),

      priority: z
        .enum(TASK_PRIORITIES)
        .optional(),

      status: z
        .enum(TASK_STATUSES)
        .optional(),

      dueDate: nullableDate.optional(),
    })
    .strict()
    .refine(
      (body) => Object.keys(body).length > 0,
      {
        message: "At least one field must be provided.",
      }
    ),
});

/**
 * GET /api/tasks/:taskId
 * DELETE /api/tasks/:taskId
 */
export const taskIdParamSchema = z.object({
  params: z.object({
    taskId: z.string().uuid("Invalid task ID."),
  }),
});

/**
 * GET /api/tasks
 */
export const listTasksSchema = z.object({
  query: z
    .object({
      status: z.enum(TASK_STATUSES).optional(),

      priority: z.enum(TASK_PRIORITIES).optional(),

      dueBefore: z.coerce.date().optional(),

      dueAfter: z.coerce.date().optional(),

      page: z.coerce
        .number()
        .int()
        .min(1)
        .default(1),

      limit: z.coerce
        .number()
        .int()
        .min(1)
        .max(100)
        .default(20),
    })
    .strict(),
});

export type CreateTaskBody = z.infer<
  typeof createTaskSchema
>["body"];

export type UpdateTaskBody = z.infer<
  typeof updateTaskSchema
>["body"];

export type ListTasksQuery = z.infer<
  typeof listTasksSchema
>["query"];