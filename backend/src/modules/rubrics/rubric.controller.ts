/**
 * File Name: rubric.controller.ts
 * Description: Handles HTTP requests for group rubrics.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { rubricService } from "./rubric.service.js";

import {
  listRubricsSchema,
  parseRubricSchema,
  rubricParamSchema,
  rubricRoadmapProposalSchema,
} from "./rubric.validation.js";

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

export const rubricController = {
  /**
   * POST /api/groups/:groupId/rubrics/parse
   * Parses pasted rubric text into weighted criteria.
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

      const body = parseRubricSchema.shape.body.parse(req.body);

      const rubric = await rubricService.create(groupId, userId, body);

      res.status(201).json({
        message: "Rubric parsed successfully.",
        data: rubric,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/rubrics
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

      const query = listRubricsSchema.shape.query.parse(req.query);

      const result = await rubricService.list(groupId, userId, query);

      res.status(200).json({
        message: "Rubrics retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/rubrics/:rubricId
   */
  async get(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, rubricId } = rubricParamSchema.shape.params.parse(
        req.params,
      );

      const rubric = await rubricService.get(groupId, userId, rubricId);

      res.status(200).json({
        message: "Rubric retrieved successfully.",
        data: rubric,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/rubrics/:rubricId/roadmap-proposals
   * Generates an editable draft roadmap from an existing rubric.
   */
  async createRoadmapProposal(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, rubricId } =
        rubricRoadmapProposalSchema.shape.params.parse(req.params);

      const proposal = await rubricService.createRoadmapProposal(
        groupId,
        userId,
        rubricId,
      );

      res.status(201).json({
        message: "Roadmap proposal generated successfully.",
        data: proposal,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/groups/:groupId/rubrics/:rubricId
   */
  async remove(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, rubricId } = rubricParamSchema.shape.params.parse(
        req.params,
      );

      await rubricService.delete(groupId, userId, rubricId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
