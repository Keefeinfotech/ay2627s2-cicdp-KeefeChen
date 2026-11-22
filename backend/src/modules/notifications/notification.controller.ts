/**
 * File Name: notification.controller.ts
 * Description: HTTP handlers for in-app notifications and device registry.
 */

import type { NextFunction, Request, Response } from "express";

import { notificationService } from "./notification.service.js";
import { AppError } from "../../shared/utils/AppError.js";

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

export const notificationController = {
  /** GET /api/notifications?page&limit&read */
  async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { page, limit, read } = req.query as unknown as {
        page?: number;
        limit?: number;
        read?: boolean;
      };

      const result = await notificationService.list(userId, {
        page,
        limit,
        read,
      });

      res.status(200).json({
        message: "Notifications retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/notifications/unread-count */
  async unreadCount(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const count = await notificationService.unreadCount(userId);
      res.status(200).json({
        message: "Unread count retrieved successfully.",
        data: { unread: count },
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/notifications/:notificationId */
  async show(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const notification = await notificationService.getById(
        userId,
        String(req.params.notificationId),
      );
      if (!notification) {
        throw new AppError(
          404,
          "NOTIFICATION_NOT_FOUND",
          "Notification not found.",
        );
      }

      res.status(200).json({
        message: "Notification retrieved successfully.",
        data: notification,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/notifications/:notificationId/read */
  async markRead(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const notification = await notificationService.markRead(
        userId,
        String(req.params.notificationId),
      );
      if (!notification) {
        throw new AppError(
          404,
          "NOTIFICATION_NOT_FOUND",
          "Notification not found.",
        );
      }

      res.status(200).json({
        message: "Notification marked as read.",
        data: notification,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/notifications/read-all */
  async markAllRead(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const updated = await notificationService.markAllRead(userId);
      res.status(200).json({
        message: "All notifications marked as read.",
        data: { updated },
      });
    } catch (error) {
      next(error);
    }
  },

  /** DELETE /api/notifications/:notificationId */
  async remove(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const notification = await notificationService.remove(
        userId,
        String(req.params.notificationId),
      );
      if (!notification) {
        throw new AppError(
          404,
          "NOTIFICATION_NOT_FOUND",
          "Notification not found.",
        );
      }

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },

  /** DELETE /api/notifications */
  async clearAll(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const deleted = await notificationService.clearAll(userId);
      res.status(200).json({
        message: "Notifications cleared.",
        data: { deleted },
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/notifications/devices */
  async registerDevice(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { token, platform } = req.body as {
        token: string;
        platform: "ios" | "android" | "web";
      };

      const device = await notificationService.registerDevice(userId, {
        token,
        platform,
      });

      res.status(201).json({
        message: "Device registered successfully.",
        data: device,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/notifications/devices */
  async listDevices(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const devices = await notificationService.listDevices(userId);
      res.status(200).json({
        message: "Devices retrieved successfully.",
        data: devices,
      });
    } catch (error) {
      next(error);
    }
  },

  /** DELETE /api/notifications/devices/:deviceId */
  async unregisterDevice(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const device = await notificationService.unregisterDevice(
        userId,
        String(req.params.deviceId),
      );
      if (!device) {
        throw new AppError(404, "DEVICE_NOT_FOUND", "Device not found.");
      }

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
