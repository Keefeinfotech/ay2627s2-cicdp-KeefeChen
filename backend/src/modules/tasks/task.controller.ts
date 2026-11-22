/**
 * File Name: task.controller.ts
 * Description: Handles HTTP requests and responses for task operations.
 * Author: Keefe Chen
 */

import type { Request, Response, NextFunction } from "express";

import { taskService } from "./task.service.js";
import logger from "../../config/logger.js";

import {
  createTaskSchema,
  listTasksSchema,
  updateTaskSchema,
  taskIdParamSchema,
} from "./task.validation.js";

import type { CreateTaskBody, UpdateTaskBody } from "./task.validation.js";
import type {
  OffsetPaginationInput,
  TaskPriority,
  TaskStatus,
} from "./task.types.js";

/**
 * Ensures the request has an authenticated user ID.
 */
function requireUserId(req: Request, res: Response): string | null {
  if (!req.userId) {
    res.status(401).json({
      code: "UNAUTHENTICATED",
      message: "Authentication is required.",
    });

    return null;
  }

  return req.userId;
}

export const taskController = {
  /**
   * POST /api/tasks
   * Creates a new task for the authenticated user.
   */
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const body = createTaskSchema.shape.body.parse(
        req.body,
      ) as CreateTaskBody;

      const task = await taskService.createTask(userId, body);

      logger.info("task.create.confirmed", {
        userId,
        taskId: task._id,
        requestId: req.requestId,
      });

      res.status(201).json({
        message: "Task created successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/tasks
   * Retrieves the authenticated user's tasks.
   */
  async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      // Parse query parameters and apply Zod defaults.
      const query = listTasksSchema.shape.query.parse(
        req.query,
      ) as OffsetPaginationInput;

      const result = await taskService.listTasks(userId, query);

      res.status(200).json({
        message: "Tasks retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/tasks/:taskId
   * Retrieves a specific task belonging to the authenticated user.
   */
  async getById(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(req.params);

      const task = await taskService.getTask(userId, taskId);

      res.status(200).json({
        message: "Task retrieved successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/tasks/:taskId
   * Updates a specific task belonging to the authenticated user.
   */
  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(req.params);

      const body = updateTaskSchema.shape.body.parse(
        req.body,
      ) as UpdateTaskBody;

      const task = await taskService.updateTask(userId, taskId, body);

      res.status(200).json({
        message: "Task updated successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/tasks/:taskId/status
   */
  async setStatus(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.params as { taskId: string };
      const { status } = req.body as { status: TaskStatus };

      const task = await taskService.updateTask(userId, taskId, { status });

      res.status(200).json({
        message: "Task status updated successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/tasks/:taskId/priority
   */
  async setPriority(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.params as { taskId: string };
      const { priority } = req.body as { priority: TaskPriority };

      const task = await taskService.updateTask(userId, taskId, { priority });

      res.status(200).json({
        message: "Task priority updated successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/tasks/:taskId/due-date
   */
  async setDueDate(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.params as { taskId: string };
      const { dueDate } = req.body as { dueDate: Date | null };

      const task = await taskService.updateTask(userId, taskId, { dueDate });

      res.status(200).json({
        message: "Task due date updated successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/tasks/:taskId/complete
   */
  async complete(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.params as { taskId: string };

      const task = await taskService.updateTask(userId, taskId, {
        status: "completed",
      });

      res.status(200).json({
        message: "Task completed successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/tasks/:taskId/reopen
   */
  async reopen(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.params as { taskId: string };

      const task = await taskService.updateTask(userId, taskId, {
        status: "todo",
      });

      res.status(200).json({
        message: "Task reopened successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/tasks/bulk
   */
  async bulkCreate(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { tasks } = req.body as {
        tasks: Parameters<typeof taskService.createTask>[1][];
      };

      const result = await taskService.bulkCreateTasks(userId, tasks);

      res.status(201).json({
        message: "Bulk task creation completed.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/tasks/bulk/status
   */
  async bulkSetStatus(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { ids, status } = req.body as { ids: string[]; status: TaskStatus };

      const result = await taskService.bulkUpdateStatus(userId, ids, status);

      res.status(200).json({
        message: "Bulk status update completed.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/tasks/bulk
   */
  async bulkDelete(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { ids } = req.body as { ids: string[] };

      const result = await taskService.bulkDeleteTasks(userId, ids);

      res.status(200).json({
        message: "Bulk delete completed.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/tasks/:taskId
   * Soft-deletes a specific task belonging to the authenticated user.
   */
  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(req.params);

      await taskService.deleteTask(userId, taskId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
