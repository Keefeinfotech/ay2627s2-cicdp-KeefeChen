/**
 * File Name: reminder.controller.ts
 * Description: Handles HTTP requests for reminders. Ownership of every
 *              reminder operation is enforced in the service layer.
 * Author: Keefe Chen
 */

import type { NextFunction, Request, Response } from "express";

import { reminderService } from "./reminder.service.js";
import { AppError } from "../../shared/utils/AppError.js";
import { taskService } from "../tasks/task.service.js";

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

const notFound = () =>
  new AppError(404, "REMINDER_NOT_FOUND", "Reminder not found.");

export const reminderController = {
  /** GET /api/reminders */
  async index(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const reminders = await reminderService.findAll(userId);
      res.status(200).json({
        message: "Reminders retrieved successfully.",
        data: reminders,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/reminders */
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { message, dueAt, taskId, recurrence, enabled } = req.body as {
        message?: string;
        dueAt?: string;
        taskId?: string | null;
        recurrence?: "none" | "daily" | "weekly" | "monthly";
        enabled?: boolean;
      };

      if (!message || !dueAt) {
        res.status(400).json({
          code: "MISSING_FIELDS",
          message: "Message and dueAt are required.",
        });
        return;
      }

      if (taskId) {
        // Verify the task belongs to this user before linking.
        await taskService.getTask(userId, taskId);
      }

      const reminder = await reminderService.create(userId, {
        message,
        dueAt,
        taskId,
        recurrence,
        enabled,
      });

      res.status(201).json({
        message: "Reminder created successfully.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/reminders/upcoming?days=7 */
  async upcoming(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const days = Number(req.query.days ?? 7);
      const reminders = await reminderService.upcoming(userId, days);

      res.status(200).json({
        message: "Upcoming reminders retrieved successfully.",
        data: reminders,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/reminders/:reminderId */
  async show(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const reminder = await reminderService.findById(
        String(req.params.reminderId),
        userId,
      );
      if (!reminder) throw notFound();

      res.status(200).json({
        message: "Reminder retrieved successfully.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/reminders/:reminderId */
  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { taskId } = req.body as { taskId?: string | null };
      if (taskId) {
        await taskService.getTask(userId, taskId);
      }

      const reminder = await reminderService.update(
        String(req.params.reminderId),
        userId,
        req.body,
      );
      if (!reminder) throw notFound();

      res.status(200).json({
        message: "Reminder updated successfully.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/reminders/:reminderId/status */
  async status(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { completed, enabled } = req.body as {
        completed?: boolean;
        enabled?: boolean;
      };

      const reminderId = String(req.params.reminderId);

      if (typeof completed === "boolean") {
        const reminder = completed
          ? await reminderService.complete(reminderId, userId)
          : await reminderService.update(reminderId, userId, {
              completed: false,
            });
        if (!reminder) throw notFound();

        res.status(200).json({
          message: "Reminder status updated successfully.",
          data: reminder,
        });
        return;
      }

      if (typeof enabled === "boolean") {
        const reminder = await reminderService.setEnabled(
          reminderId,
          userId,
          enabled,
        );
        if (!reminder) throw notFound();

        res.status(200).json({
          message: "Reminder status updated successfully.",
          data: reminder,
        });
        return;
      }

      res.status(400).json({
        code: "MISSING_FIELDS",
        message: "Provide 'completed' or 'enabled'.",
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/reminders/:reminderId/complete */
  async complete(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const reminder = await reminderService.complete(
        String(req.params.reminderId ?? req.params.id),
        userId,
      );
      if (!reminder) throw notFound();

      res.status(200).json({
        message: "Reminder marked as completed.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /** DELETE /api/reminders/:reminderId */
  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const reminder = await reminderService.delete(
        String(req.params.reminderId ?? req.params.id),
        userId,
      );
      if (!reminder) throw notFound();

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/reminders/pending */
  async pending(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const now = new Date();
      const pending = await reminderService.findPending(userId, now);

      res.status(200).json({
        message: "Pending reminders retrieved successfully.",
        data: pending,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/tasks/:taskId/reminders */
  async listForTask(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const taskId = String(req.params.taskId);
      await taskService.getTask(userId, taskId); // ownership check

      const reminders = await reminderService.findByTask(userId, taskId);
      res.status(200).json({
        message: "Task reminders retrieved successfully.",
        data: reminders,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/tasks/:taskId/reminders */
  async createForTask(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const taskId = String(req.params.taskId);
      await taskService.getTask(userId, taskId); // ownership check

      const { message, dueAt, recurrence, enabled } = req.body as {
        message?: string;
        dueAt?: string;
        recurrence?: "none" | "daily" | "weekly" | "monthly";
        enabled?: boolean;
      };

      if (!message || !dueAt) {
        res.status(400).json({
          code: "MISSING_FIELDS",
          message: "Message and dueAt are required.",
        });
        return;
      }

      const reminder = await reminderService.create(userId, {
        message,
        dueAt,
        taskId,
        recurrence,
        enabled,
      });

      res.status(201).json({
        message: "Task reminder created successfully.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },
};
