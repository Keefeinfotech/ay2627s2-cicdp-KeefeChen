/**
 * File Name: task.routes.ts
 * Description: Defines authenticated task API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { taskController } from "./task.controller.js";
import { reminderController } from "../reminders/reminder.controller.js";
import {
  createTaskReminderSchema,
  taskReminderParamsSchema,
} from "../reminders/reminder.validation.js";

import {
  bulkCreateTasksSchema,
  bulkDeleteTasksSchema,
  bulkUpdateStatusSchema,
  createTaskSchema,
  listTasksSchema,
  setTaskDueDateSchema,
  setTaskPrioritySchema,
  setTaskStatusSchema,
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
router.get("/", validateRequest(listTasksSchema), taskController.list);

/**
 * POST /api/tasks
 * Creates a new task.
 */
router.post("/", validateRequest(createTaskSchema), taskController.create);

/**
 * POST /api/tasks/bulk
 * Bulk-create up to 100 tasks.
 */
router.post(
  "/bulk",
  validateRequest(bulkCreateTasksSchema),
  taskController.bulkCreate,
);

/**
 * PATCH /api/tasks/bulk/status
 * Bulk-update the status of up to 100 tasks.
 */
router.patch(
  "/bulk/status",
  validateRequest(bulkUpdateStatusSchema),
  taskController.bulkSetStatus,
);

/**
 * DELETE /api/tasks/bulk
 * Bulk soft-delete up to 100 tasks.
 */
router.delete(
  "/bulk",
  validateRequest(bulkDeleteTasksSchema),
  taskController.bulkDelete,
);

/**
 * GET /api/tasks/:taskId/reminders
 * Lists reminders attached to a task owned by the user.
 */
router.get(
  "/:taskId/reminders",
  validateRequest(taskReminderParamsSchema),
  reminderController.listForTask,
);

/**
 * POST /api/tasks/:taskId/reminders
 * Attaches a reminder to a task owned by the user.
 */
router.post(
  "/:taskId/reminders",
  validateRequest(createTaskReminderSchema),
  reminderController.createForTask,
);

/**
 * GET /api/tasks/:taskId
 * Retrieves a specific task.
 */
router.get(
  "/:taskId",
  validateRequest(taskIdParamSchema),
  taskController.getById,
);

/**
 * PATCH /api/tasks/:taskId
 * Updates a specific task.
 */
router.patch(
  "/:taskId",
  validateRequest(updateTaskSchema),
  taskController.update,
);

/**
 * PATCH /api/tasks/:taskId/status
 * Sets only the status of a task.
 */
router.patch(
  "/:taskId/status",
  validateRequest(setTaskStatusSchema),
  taskController.setStatus,
);

/**
 * PATCH /api/tasks/:taskId/priority
 * Sets only the priority of a task.
 */
router.patch(
  "/:taskId/priority",
  validateRequest(setTaskPrioritySchema),
  taskController.setPriority,
);

/**
 * PATCH /api/tasks/:taskId/due-date
 * Sets (or clears, with null) the due date of a task.
 */
router.patch(
  "/:taskId/due-date",
  validateRequest(setTaskDueDateSchema),
  taskController.setDueDate,
);

/**
 * POST /api/tasks/:taskId/complete
 * Marks a task as completed.
 */
router.post(
  "/:taskId/complete",
  validateRequest(taskIdParamSchema),
  taskController.complete,
);

/**
 * POST /api/tasks/:taskId/reopen
 * Reopens a completed task.
 */
router.post(
  "/:taskId/reopen",
  validateRequest(taskIdParamSchema),
  taskController.reopen,
);

/**
 * DELETE /api/tasks/:taskId
 * Soft-deletes a specific task.
 */
router.delete(
  "/:taskId",
  validateRequest(taskIdParamSchema),
  taskController.remove,
);

export default router;
