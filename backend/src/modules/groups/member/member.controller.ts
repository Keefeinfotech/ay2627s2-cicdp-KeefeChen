/**
 * File Name: member.controller.ts
 * Description: Handles HTTP requests for group member operations.
 */

import type {
  Request,
  Response,
  NextFunction,
} from "express";

import { MemberService } from "./member.service.js";

const memberService = new MemberService();

function getAuthenticatedUserId(req: Request): string {
  const userId = req.userId;

  if (!userId) {
    throw new Error("Authentication required.");
  }

  return userId;
}

function getGroupId(req: Request): string {
  const groupId = req.params.groupId;

  if (typeof groupId !== "string" || groupId.length === 0) {
    throw new Error("Invalid group ID.");
  }

  return groupId;
}

export class MemberController {
  /**
   * GET /api/groups/:groupId/members
   */
  static list = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const groupId = getGroupId(req);

      const requestedPage = Number(req.query.page);
      const requestedLimit = Number(req.query.limit);

      const page =
        Number.isInteger(requestedPage) && requestedPage > 0
          ? requestedPage
          : 1;

      const limit =
        Number.isInteger(requestedLimit) && requestedLimit > 0
          ? Math.min(requestedLimit, 100)
          : 50;

      const result = await memberService.list(groupId, userId, {
        page,
        limit,
      });

      return res.status(200).json({
        message: "Group members retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      return next(error);
    }
  };
}
