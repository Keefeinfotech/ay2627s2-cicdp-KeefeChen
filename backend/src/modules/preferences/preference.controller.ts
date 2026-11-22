/**
 * File Name: preference.controller.ts
 * Description: HTTP handlers for user preferences.
 */

import type { NextFunction, Request, Response } from "express";

import { preferenceService } from "./preference.service.js";

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

export const preferenceController = {
  /** GET /api/preferences */
  async get(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await preferenceService.get(userId);
      res.status(200).json({
        message: "Preferences retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/preferences */
  async update(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await preferenceService.update(userId, req.body);
      res.status(200).json({
        message: "Preferences updated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/preferences/notifications */
  async updateNotifications(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await preferenceService.updateNotifications(
        userId,
        req.body,
      );
      res.status(200).json({
        message: "Notification preferences updated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/preferences/appearance */
  async updateAppearance(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await preferenceService.updateAppearance(userId, req.body);
      res.status(200).json({
        message: "Appearance preferences updated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** PATCH /api/preferences/timezone */
  async updateTimezone(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { timezone } = req.body as { timezone: string };
      const data = await preferenceService.updateTimezone(userId, timezone);
      res.status(200).json({
        message: "Timezone updated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },
};
