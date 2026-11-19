/**
 * File Name: analytics.controller.ts
 * Description: Handles HTTP requests for productivity analytics and priority suggestions.
 */

import type { Request, Response, NextFunction } from "express";

import { analyticsService } from "./analytics.service.js";

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

export const analyticsController = {
  /** GET /api/analytics/weekly?weeks=8 */
  async weekly(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const weeks = Number(req.query.weeks ?? 8);
      const summary = await analyticsService.getWeeklySummary(userId, weeks);

      res.status(200).json({
        message: "Weekly productivity summary retrieved successfully.",
        data: summary,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/priority-suggestions?limit=20 */
  async prioritySuggestions(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const limit = Number(req.query.limit ?? 20);
      const result = await analyticsService.getPrioritySuggestions(userId, limit);

      res.status(200).json({
        message: "Priority suggestions generated successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/analytics/priority-suggestions/apply */
  async applyPrioritySuggestions(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const result = await analyticsService.applyPrioritySuggestions(userId);

      res.status(200).json({
        message: "Priority suggestions applied successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },
};
