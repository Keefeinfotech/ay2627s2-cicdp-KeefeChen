
/**
 * File Name: task.controller.ts
 * Description: Handles HTTP requests and responses for task operations.
 * Author: Keefe Chen
 */

import type {
  Request,
  Response,
  NextFunction,
} from "express";

import { taskService } from "./task.service.js";

import {
  createTaskSchema,
  listTasksSchema,
  updateTaskSchema,
  taskIdParamSchema,
} from "./task.validation.js";

import type {
  CreateTaskBody,
  UpdateTaskBody,
} from "./task.validation.js";

/**
 * Ensures the request has an authenticated user ID.
 */
function requireUserId(
  req: Request,
  res: Response
): string | null {
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
  async create(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const body = createTaskSchema.shape.body.parse(
        req.body
      ) as CreateTaskBody;

      const task = await taskService.createTask(
        userId,
        body
      );

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
  async list(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      // Parse query parameters and apply Zod defaults.
      const query = listTasksSchema.shape.query.parse(
        req.query
      );

      // This endpoint currently supports offset pagination.
      if (query.paginationType === "cursor") {
        res.status(400).json({
          code: "UNSUPPORTED_PAGINATION_TYPE",
          message: "Cursor pagination is not currently supported.",
        });

        return;
      }

      const result = await taskService.listTasks(
        userId,
        query
      );

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
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(
        req.params
      );

      const task = await taskService.getTask(
        userId,
        taskId
      );

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
  async update(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(
        req.params
      );

      const body = updateTaskSchema.shape.body.parse(
        req.body
      ) as UpdateTaskBody;

      const task = await taskService.updateTask(
        userId,
        taskId,
        body
      );

      res.status(200).json({
        message: "Task updated successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/tasks/:taskId
   * Soft-deletes a specific task belonging to the authenticated user.
   */
  async remove(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);

      if (!userId) return;

      const { taskId } = taskIdParamSchema.shape.params.parse(
        req.params
      );

      await taskService.deleteTask(
        userId,
        taskId
      );

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
