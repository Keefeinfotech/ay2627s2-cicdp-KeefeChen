/**
 * File Name: session.controller.ts
 * Description: Handles HTTP requests for group study sessions.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { sessionService } from "./session.service.js";

import {
  createSessionSchema,
  listSessionsSchema,
  sessionParamSchema,
  updateSessionSchema,
} from "./session.validation.js";

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

export const sessionController = {
  /**
   * POST /api/groups/:groupId/sessions
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

      const body = createSessionSchema.shape.body.parse(req.body);

      const session = await sessionService.create(
        groupId,
        userId,
        body,
      );

      res.status(201).json({
        message: "Session scheduled successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/sessions
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

      const query = listSessionsSchema.shape.query.parse(req.query);

      const result = await sessionService.list(groupId, userId, {
        status: query.status,
        from: query.from,
        to: query.to,
        page: query.page,
        limit: query.limit,
      });

      res.status(200).json({
        message: "Sessions retrieved successfully.",
        data: result.items,
        pagination: result.pagination,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * GET /api/groups/:groupId/sessions/:sessionId
   */
  async get(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      const session = await sessionService.get(
        groupId,
        userId,
        sessionId,
      );

      res.status(200).json({
        message: "Session retrieved successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/groups/:groupId/sessions/:sessionId
   */
  async update(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const parsed = updateSessionSchema.parse(req);
      const { groupId, sessionId } = parsed.params;
      const body = parsed.body;

      const session = await sessionService.update(
        groupId,
        userId,
        sessionId,
        body,
      );

      res.status(200).json({
        message: "Session updated successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/sessions/:sessionId/join
   */
  async join(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      const session = await sessionService.join(
        groupId,
        userId,
        sessionId,
      );

      res.status(200).json({
        message: "Joined session successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/sessions/:sessionId/leave
   */
  async leave(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      const session = await sessionService.leave(
        groupId,
        userId,
        sessionId,
      );

      res.status(200).json({
        message: "Left session successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/sessions/:sessionId/cancel
   */
  async cancel(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      const session = await sessionService.cancel(
        groupId,
        userId,
        sessionId,
      );

      res.status(200).json({
        message: "Session cancelled successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/groups/:groupId/sessions/:sessionId/complete
   */
  async complete(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      const session = await sessionService.complete(
        groupId,
        userId,
        sessionId,
      );

      res.status(200).json({
        message: "Session completed successfully.",
        data: session,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/groups/:groupId/sessions/:sessionId
   */
  async remove(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const { groupId, sessionId } =
        sessionParamSchema.shape.params.parse(req.params);

      await sessionService.delete(groupId, userId, sessionId);

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  },
};
