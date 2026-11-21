/**
 * File Name: assistant.controller.ts
 * Description: HTTP handlers for the confirmation-gated assistant flow.
 */

import type { NextFunction, Request, Response } from "express";

import { assistantService } from "./assistant.service.js";

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

export const assistantController = {
  /** POST /api/assistant/interpret */
  async interpret(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.interpret(userId, req.body);
      res.status(200).json({
        message: "Draft interpreted successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/assistant/clarify */
  async clarify(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.clarify(userId, req.body);
      res.status(200).json({
        message: "Draft clarified successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/assistant/preview */
  async preview(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.preview(userId, req.body);
      res.status(200).json({
        message: "Preview generated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/assistant/confirm */
  async confirm(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.confirm(userId, req.body);
      res.status(201).json({
        message: "Task created successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/assistant/cancel */
  async cancel(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.cancel(userId, req.body);
      res.status(200).json({
        message: "Draft cancelled.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },

  /** POST /api/assistant/suggestions */
  async suggestions(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const data = await assistantService.suggestions(userId);
      res.status(200).json({
        message: "Suggestions generated successfully.",
        data,
      });
    } catch (error) {
      next(error);
    }
  },
};
