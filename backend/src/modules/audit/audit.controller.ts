/**
 * File Name: audit.controller.ts
 * Description: Handles HTTP requests for the group activity trail.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { AppError } from "../../shared/utils/AppError.js";
import { auditService } from "./audit.service.js";

import type { ListAuditQuery } from "./audit.types.js";

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

function parseQuery(req: Request): ListAuditQuery {
  const query = req.query as Record<string, string | string[] | undefined>;

  const asNumber = (value: unknown, fallback: number): number => {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  };

  const action =
    typeof query.action === "string" && query.action.trim().length > 0
      ? query.action.trim().slice(0, 80)
      : undefined;

  return {
    page: asNumber(query.page, 1),
    limit: Math.min(asNumber(query.limit, 20), 100),
    action,
  };
}

export const auditController = {
  /**
   * GET /api/groups/:groupId/audit
   * Lists activity events for the group.
   */
  async list(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const groupId = req.params.groupId;

      if (typeof groupId !== "string" || !groupId) {
        throw new AppError(400, "INVALID_GROUP_ID", "A group ID is required.");
      }

      const result = await auditService.list(
        groupId,
        userId,
        parseQuery(req),
      );

      res.status(200).json({
        message: "Activity retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },
};
