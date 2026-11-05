/**
 * File Name: sync.controller.ts
 * Description: Handles HTTP requests for the change feed.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { AppError } from "../../shared/utils/AppError.js";
import { syncService } from "./sync.service.js";

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

export const syncController = {
  /**
   * GET /api/sync/changes
   * Returns tasks updated since the supplied timestamp.
   */
  async changes(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const sinceParam = req.query.since;

      let since: Date | null = null;

      if (typeof sinceParam === "string" && sinceParam.trim().length > 0) {
        const parsed = new Date(sinceParam);

        if (Number.isNaN(parsed.getTime())) {
          throw new AppError(
            400,
            "INVALID_SYNC_CURSOR",
            "The 'since' query parameter must be a valid ISO date.",
          );
        }

        since = parsed;
      }

      const result = await syncService.getChanges(userId, since);

      res.status(200).json({
        message: "Changes retrieved successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },
};
