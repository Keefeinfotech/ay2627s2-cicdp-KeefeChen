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
  /** GET /api/analytics/overview */
  async overview(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await analyticsService.getOverview(userId);
      res.status(200).json({
        message: "Analytics overview retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/daily?days=14 */
  async daily(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const days = Number(req.query.days ?? 14);
      const data = await analyticsService.getDaily(userId, days);
      res.status(200).json({
        message: "Daily analytics retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/monthly?months=6 */
  async monthly(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const months = Number(req.query.months ?? 6);
      const data = await analyticsService.getMonthly(userId, months);
      res.status(200).json({
        message: "Monthly analytics retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/completion-rate?weeks=8 */
  async completionRate(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const weeks = Number(req.query.weeks ?? 8);
      const data = await analyticsService.getCompletionRate(userId, weeks);
      res.status(200).json({
        message: "Completion rate retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/task-trends?months=6 */
  async taskTrends(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const months = Number(req.query.months ?? 6);
      const data = await analyticsService.getTaskTrends(userId, months);
      res.status(200).json({
        message: "Task trends retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/overdue?limit=50 */
  async overdue(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const limit = Number(req.query.limit ?? 50);
      const items = await analyticsService.getOverdue(userId, limit);
      res.status(200).json({
        message: "Overdue tasks retrieved successfully.",
        data: { items, count: items.length },
      });
    } catch (error) {
      next(error);
    }
  },

  /** GET /api/analytics/productivity-summary */
  async productivitySummary(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await analyticsService.getProductivitySummary(userId);
      res.status(200).json({
        message: "Productivity summary retrieved successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

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
      const result = await analyticsService.getPrioritySuggestions(
        userId,
        limit,
      );

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
