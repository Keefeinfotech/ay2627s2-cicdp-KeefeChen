/**
 * File Name: task.routes.ts
 * Description: Defines authenticated task API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { taskController } from "./task.controller.js";

import {
  createTaskSchema,
  listTasksSchema,
  taskIdParamSchema,
  updateTaskSchema,
} from "./task.validation.js";

const router = Router();

/**
 * All task endpoints require authentication.
 */
router.use(authenticate);

/**
 * GET /api/tasks
 * Retrieves the authenticated user's tasks.
 */
router.get(
  "/",
  validateRequest(listTasksSchema),
  taskController.list
);

/**
 * POST /api/tasks
 * Creates a new task.
 */
router.post(
  "/",
  validateRequest(createTaskSchema),
  taskController.create
);

/**
 * GET /api/tasks/:taskId
 * Retrieves a specific task.
 */
router.get(
  "/:taskId",
  validateRequest(taskIdParamSchema),
  taskController.getById
);

/**
 * PATCH /api/tasks/:taskId
 * Updates a specific task.
 */
router.patch(
  "/:taskId",
  validateRequest(updateTaskSchema),
  taskController.update
);

/**
 * DELETE /api/tasks/:taskId
 * Soft-deletes a specific task.
 */
router.delete(
  "/:taskId",
  validateRequest(taskIdParamSchema),
  taskController.remove
);

export default router;