/**
 * File Name: progress.controller.ts
 * Description: Handles HTTP requests for group progress.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { progressService } from "./progress.service.js";

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

export const progressController = {
  /**
   * GET /api/groups/:groupId/progress
   */
  async get(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const groupId = req.params.groupId;

      if (typeof groupId !== "string" || !groupId) {
        res.status(400).json({
          code: "INVALID_GROUP_ID",
          message: "A group ID is required.",
        });
        return;
      }

      const progress = await progressService.get(groupId, userId);

      res.status(200).json({
        message: "Progress retrieved successfully.",
        data: progress,
      });
    } catch (error) {
      next(error);
    }
  },
};
