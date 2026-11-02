/**
 * File Name: group.controller.ts
 * Description: Handles HTTP requests for group operations.
 * Author: Keefe Chen
 */

import type {
  Request,
  Response,
  NextFunction,
} from "express";

import { GroupService } from "./group.services.js";

const groupService = new GroupService();

/**
 * Extracts the authenticated user's ID.
 */
function getAuthenticatedUserId(req: Request): string {
  const userId = req.userId;

  if (!userId) {
    throw new Error("Authentication required.");
  }

  return userId;
}

/**
 * Extracts and validates the group ID from route parameters.
 */
function getGroupId(req: Request): string {
  const groupId = req.params.groupId;

  if (typeof groupId !== "string") {
    throw new Error("Invalid group ID.");
  }

  return groupId;
}

export class GroupController {
  /**
   * POST /groups
   *
   * Creates a new group for the authenticated user.
   */
  static create = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);

      const group = await groupService.create(
        userId,
        req.body,
      );

      return res.status(201).json({
        message: "Group created successfully.",
        data: group,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * GET /groups
   *
   * Retrieves groups belonging to the authenticated user.
   */
  static list = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);

      // Convert and validate pagination values.
      const requestedPage = Number(req.query.page);
      const requestedLimit = Number(req.query.limit);

      const page =
        Number.isInteger(requestedPage) && requestedPage > 0
          ? requestedPage
          : 1;

      const limit =
        Number.isInteger(requestedLimit) && requestedLimit > 0
          ? Math.min(requestedLimit, 100)
          : 10;

      // Only accept a single search string.
      const search =
        typeof req.query.search === "string"
          ? req.query.search.trim()
          : undefined;

      const result = await groupService.list(userId, {
        page,
        limit,
        search,
      });

      return res.status(200).json({
        message: "Groups retrieved successfully.",
        data: result,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * GET /groups/:groupId
   *
   * Retrieves a specific group.
   */
  static get = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const groupId = getGroupId(req);

      const group = await groupService.get(
        groupId,
        userId,
      );

      return res.status(200).json({
        message: "Group retrieved successfully.",
        data: group,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * PATCH /groups/:groupId
   *
   * Updates an existing group.
   */
  static update = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const groupId = getGroupId(req);

      const updatedGroup = await groupService.update(
        groupId,
        userId,
        req.body,
      );

      return res.status(200).json({
        message: "Group updated successfully.",
        data: updatedGroup,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * DELETE /groups/:groupId
   *
   * Archives a group instead of permanently deleting it.
   */
  static archive = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const groupId = getGroupId(req);

      await groupService.archive(
        groupId,
        userId,
      );

      return res.status(200).json({
        message: "Group archived successfully.",
      });
    } catch (error) {
      return next(error);
    }
  };
}