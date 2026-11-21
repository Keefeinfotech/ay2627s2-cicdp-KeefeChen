/**
 * File Name: sync.validation.ts
 * Description: Zod schemas for sync push/pull endpoints.
 */

import { z } from "zod";

const taskCreatePayload = z
  .object({
    id: z.string().uuid().optional(),
    title: z.string().trim().min(1).max(150),
    description: z.string().max(5000).nullish(),
    course: z.string().trim().max(120).optional(),
    tags: z.array(z.string().trim().min(1).max(24)).max(8).optional(),
    groupId: z.string().uuid().nullish(),
    assigneeId: z.string().uuid().nullish(),
    assigneeName: z.string().max(120).nullish(),
    reminderAt: z.coerce.date().nullish(),
    priority: z.enum(["low", "medium", "high", "urgent"]).optional(),
    dueDate: z.coerce.date().nullish(),
  })
  .strict();

const taskUpdatePayload = z
  .object({
    taskId: z.string().uuid("Invalid task ID."),
    title: z.string().trim().min(1).max(150).optional(),
    description: z.string().max(5000).nullish(),
    course: z.string().trim().max(120).optional(),
    tags: z.array(z.string().trim().min(1).max(24)).max(8).optional(),
    priority: z.enum(["low", "medium", "high", "urgent"]).optional(),
    status: z.enum(["todo", "in_progress", "completed", "archived"]).optional(),
    dueDate: z.coerce.date().nullish(),
    reminderAt: z.coerce.date().nullish(),
    expectedUpdatedAt: z.coerce.date().optional(),
  })
  .strict();

const taskDeletePayload = z
  .object({
    taskId: z.string().uuid("Invalid task ID."),
  })
  .strict();

export const syncOperationSchema = z.discriminatedUnion("type", [
  z
    .object({
      opId: z.string().uuid(),
      type: z.literal("task.create"),
      payload: taskCreatePayload,
    })
    .strict(),
  z
    .object({
      opId: z.string().uuid(),
      type: z.literal("task.update"),
      payload: taskUpdatePayload,
    })
    .strict(),
  z
    .object({
      opId: z.string().uuid(),
      type: z.literal("task.delete"),
      payload: taskDeletePayload,
    })
    .strict(),
]);

export const syncPushSchema = z.object({
  body: z
    .object({
      operations: z
        .array(syncOperationSchema)
        .min(1, "At least one operation is required.")
        .max(50, "A maximum of 50 operations can be pushed at once."),
    })
    .strict(),
});

export const resolveConflictSchema = z.object({
  body: z
    .object({
      taskId: z.string().uuid("Invalid task ID."),
      resolution: z.enum(["client", "server"]),
      // Required when resolution === "client": the state the client wants applied.
      clientState: taskUpdatePayload.partial().optional(),
    })
    .strict()
    .refine((b) => b.resolution !== "client" || b.clientState !== undefined, {
      message: "clientState is required when resolution is 'client'.",
    }),
});

export type SyncPushBody = z.infer<typeof syncPushSchema>["body"];
export type ResolveConflictBody = z.infer<typeof resolveConflictSchema>["body"];
