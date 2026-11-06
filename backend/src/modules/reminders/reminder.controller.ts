/**
 * File Name: reminder.controller.ts
 * Description: Handles HTTP requests for reminders.
 * Author: Keefe Chen
 */

import type { NextFunction, Request, Response } from "express";
import { reminderService } from "./reminder.service.js";

export const reminderController = {
  /**
   * GET /api/reminders
   */
  async index(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).userId;
      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const reminders = await reminderService.findAll(userId);
      res.status(200).json({
        message: "Reminders retrieved successfully.",
        data: reminders,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/reminders
   */
  async create(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).userId;
      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const { message, dueAt } = req.body;
      if (!message || !dueAt) {
        res.status(400).json({
          code: "MISSING_FIELDS",
          message: "Message and dueAt are required.",
        });
        return;
      }

      const reminder = await reminderService.create(userId, message, new Date(dueAt));
      res.status(201).json({
        message: "Reminder created successfully.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/reminders/:id/complete
   */
  async complete(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).userId;
      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const id = req.params.id as string;
      const reminder = await reminderService.complete(id);

      if (!reminder) {
        res.status(404).json({
          code: "REMINDER_NOT_FOUND",
          message: "Reminder not found.",
        });
        return;
      }

      res.status(200).json({
        message: "Reminder marked as completed.",
        data: reminder,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/reminders/:id
   */
  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).userId;
      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const id = req.params.id as string;
      const reminder = await reminderService.delete(id);

      if (!reminder) {
        res.status(404).json({
          code: "REMINDER_NOT_FOUND",
          message: "Reminder not found.",
        });
        return;
      }

      res.status(200).json({
        message: "Reminder deleted successfully.",
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/reminders/pending
   */
  async pending(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = (req as any).userId;
      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

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
};