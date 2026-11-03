/**
 * File Name: roadmap.controller.ts
 * Description: Handles HTTP requests for group roadmaps.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { AppError } from "../../shared/utils/AppError.js";
import { roadmapService } from "./roadmap.service.js";

import {
  approveRoadmapSchema,
  createRoadmapSchema,
  listRoadmapsSchema,
  roadmapParamSchema,
  updateRoadmapItemSchema,
  updateRoadmapSchema,
} from "./roadmap.validation.js";

import type {
  CreateRoadmapInput,
  RoadmapItemStatus,
  RoadmapStatus,
  UpdateRoadmapInput,
} from "./roadmap.types.js";

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

function requireGroupId(req: Request, res: Response): string | null {
  const groupId = req.params.groupId;

  if (typeof groupId !== "string" || !groupId) {
    res.status(400).json({
      code: "INVALID_GROUP_ID",
      message: "A group ID is required.",
    });

    return null;
  }

  return groupId;
}

export const roadmapController = {
  /**
   * POST /api/groups/:groupId/roadmap
   */
  async create(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const groupId = requireGroupId(req, res);
      if (!groupId) return;

      const body = createRoadmapSchema.shape.body.parse(
        req.body,
      ) as CreateRoadmapInput;

      const roadmap = await roadmapService.create(
        groupId,
        userId,
        body,
      );

      res.status(201).json({
        message: "Roadmap created successfully.",
        data: roadmap,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/roadmap
   */
  async list(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const groupId = requireGroupId(req, res);
      if (!groupId) return;

      const query = listRoadmapsSchema.shape.query.parse(req.query);

      const result = await roadmapService.list(groupId, userId, {
        page: query.page,
        limit: query.limit,
        status: query.status as RoadmapStatus | undefined,
      });

      res.status(200).json({
        message: "Roadmaps retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/roadmap/:roadmapId
   */
  async get(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, roadmapId } = roadmapParamSchema.shape.params.parse(
        req.params,
      );

      const roadmap = await roadmapService.get(
        groupId,
        userId,
        roadmapId,
      );

      res.status(200).json({
        message: "Roadmap retrieved successfully.",
        data: roadmap,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/groups/:groupId/roadmap/:roadmapId
   */
  async update(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const parsed = updateRoadmapSchema.parse(req);
      const { groupId, roadmapId } = parsed.params;
      const body = parsed.body as UpdateRoadmapInput;

      const roadmap = await roadmapService.update(
        groupId,
        userId,
        roadmapId,
        body,
      );

      res.status(200).json({
        message: "Roadmap updated successfully.",
        data: roadmap,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/roadmap/:roadmapId/approve
   */
  async approve(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, roadmapId } = approveRoadmapSchema.shape.params.parse(
        req.params,
      );

      const roadmap = await roadmapService.approve(
        groupId,
        userId,
        roadmapId,
      );

      res.status(200).json({
        message: "Roadmap approved successfully.",
        data: roadmap,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/groups/:groupId/roadmap/:roadmapId/items/:itemId
   */
  async updateItem(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const parsed = updateRoadmapItemSchema.parse(req);
      const { groupId, roadmapId, itemId } = parsed.params;
      const status = parsed.body.status as RoadmapItemStatus | undefined;

      const roadmap = await roadmapService.updateItem(
        groupId,
        userId,
        roadmapId,
        itemId,
        {
          status,
          title: parsed.body.title,
          estimateHours: parsed.body.estimateHours,
        },
      );

      res.status(200).json({
        message: "Roadmap item updated successfully.",
        data: roadmap,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/groups/:groupId/roadmap/:roadmapId
   */
  async remove(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const params = roadmapParamSchema.shape.params.parse(req.params);

      if (!params || !req.params.groupId) {
        throw new AppError(400, "INVALID_GROUP_ID", "A group ID is required.");
      }

      const { groupId, roadmapId } = params;

      await roadmapService.delete(groupId, userId, roadmapId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
