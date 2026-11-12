/**
 * File Name: admin.controller.ts
 * Description: HTTP handlers for the administrative module. Validation errors
 *              return 400 with a stable code; business errors flow through the
 *              central error handler via next(error).
 * Author: Keefe Chen
 */

import type { NextFunction, Request, Response } from "express";

import {
  listUsersQuerySchema,
  updateUserStatusBodySchema,
} from "./admin.validation.js";
import { getStats, listUsers, setUserStatus } from "./admin.service.js";

export const adminController = {
  /**
   * GET /api/admin/users
   *
   * Paginated, searchable, status-filterable list of registered users.
   * Sensitive fields are never returned.
   */
  async listUsers(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const parsed = listUsersQuerySchema.safeParse(req.query);
      if (!parsed.success) {
        res.status(400).json({
          code: "INVALID_QUERY",
          message: "Invalid query parameters.",
          errors: parsed.error.issues.map((issue) => issue.message),
        });
        return;
      }

      const result = await listUsers(parsed.data);
      res.status(200).json({
        message: "Users retrieved successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/admin/users/:id/status
   *
   * Activates or deactivates an account. Administrators cannot deactivate
   * themselves, and the last active administrator cannot be deactivated.
   */
  async setUserStatus(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const actorId = req.userId;
      if (!actorId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const targetUserId = req.params.id;
      if (typeof targetUserId !== "string" || targetUserId.trim() === "") {
        res.status(400).json({
          code: "INVALID_USER_ID",
          message: "A user id path parameter is required.",
        });
        return;
      }

      const parsed = updateUserStatusBodySchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          code: "INVALID_BODY",
          message: "status must be one of: active, disabled.",
          errors: parsed.error.issues.map((issue) => issue.message),
        });
        return;
      }

      const updated = await setUserStatus(
        actorId,
        targetUserId,
        parsed.data.status,
      );
      res.status(200).json({
        message: "User status updated successfully.",
        data: updated,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/admin/stats
   *
   * Aggregated platform statistics derived from live MongoDB data.
   */
  async getStats(
    _req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const stats = await getStats();
      res.status(200).json({
        message: "Administrative statistics retrieved successfully.",
        data: stats,
      });
    } catch (error) {
      next(error);
    }
  },
};
