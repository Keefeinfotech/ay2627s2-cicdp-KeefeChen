
/**
 * File Name: task.validator.ts
 * Description: Validates task request parameters, query strings and payloads.
 * Author: Keefe Chen
 */

import { Request, Response, NextFunction } from "express";
import { z } from "zod";

/**
 * Validates MongoDB ObjectId values.
 * MongoDB ObjectIds must contain exactly 24 hexadecimal characters.
 */
const objectIdSchema = z
  .string()
  .regex(/^[a-fA-F0-9]{24}$/, "Invalid MongoDB ObjectId.");

/**
 * Validates task ID route parameters.
 */
export const taskIdParamSchema = z.object({
  taskId: objectIdSchema,
}).strict();

/**
 * Validates supported task statuses.
 */
const taskStatusSchema = z.enum([
  "TODO",
  "IN_PROGRESS",
  "COMPLETED",
]);

/**
 * Validates supported task priorities.
 */
const taskPrioritySchema = z.enum([
  "LOW",
  "MEDIUM",
  "HIGH",
]);

/**
 * Validates task creation payloads.
 *
 * createdBy is excluded because it must be obtained
 * from the authenticated user.
 */
export const createTaskSchema = z.object({
  title: z.string().trim().min(1).max(150),

  description: z.string().trim().max(2000).optional(),

  assignedTo: objectIdSchema.nullable().optional(),

  groupId: objectIdSchema.nullable().optional(),

  status: taskStatusSchema.optional(),

  priority: taskPrioritySchema.optional(),

  dueDate: z.coerce.date().nullable().optional(),
}).strict();

/**
 * Validates task update payloads.
 *
 * Only explicitly permitted task fields can be updated.
 * At least one field must be provided.
 */
export const updateTaskSchema = z.object({
  title: z.string().trim().min(1).max(150).optional(),

  description: z.string().trim().max(2000).nullable().optional(),

  assignedTo: objectIdSchema.nullable().optional(),

  groupId: objectIdSchema.nullable().optional(),

  status: taskStatusSchema.optional(),

  priority: taskPrioritySchema.optional(),

  dueDate: z.coerce.date().nullable().optional(),
})
  .strict()
  .refine(
    (data) => Object.keys(data).length > 0,
    "At least one field must be provided for an update."
  );

/**
 * Validates task retrieval query parameters.
 *
 * Supports filtering, pagination and result limits.
 */
export const getTasksQuerySchema = z.object({
  status: taskStatusSchema.optional(),

  priority: taskPrioritySchema.optional(),

  groupId: objectIdSchema.optional(),

  page: z.coerce.number().int().positive().default(1),

  limit: z.coerce.number().int().min(1).max(100).default(20),
}).strict();

/**
 * Validates task ID route parameters.
 */
export const validateTaskId = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const result = taskIdParamSchema.safeParse(req.params);

  if (!result.success) {
    res.status(400).json({
      success: false,
      message: "Invalid task ID.",
      errors: result.error.flatten(),
    });
    return;
  }

  next();
};

/**
 * Validates task creation requests.
 */
export const validateCreateTask = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const result = createTaskSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      success: false,
      message: "Invalid task data.",
      errors: result.error.flatten(),
    });
    return;
  }

  req.body = result.data;
  next();
};

/**
 * Validates task update requests.
 */
export const validateUpdateTask = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const result = updateTaskSchema.safeParse(req.body);

  if (!result.success) {
    res.status(400).json({
      success: false,
      message: "Invalid task update.",
      errors: result.error.flatten(),
    });
    return;
  }

  req.body = result.data;
  next();
};

/**
 * Validates task retrieval query parameters.
 *
 * Parsed filters are stored in res.locals to avoid
 * directly modifying Express query parameters.
 */
export const validateGetTasks = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const result = getTasksQuerySchema.safeParse(req.query);

  if (!result.success) {
    res.status(400).json({
      success: false,
      message: "Invalid query parameters.",
      errors: result.error.flatten(),
    });
    return;
  }

  res.locals.taskFilters = result.data;
  next();
};
