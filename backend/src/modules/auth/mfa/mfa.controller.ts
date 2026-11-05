/**
 * File Name: mfa.controller.ts
 * Description: Handles HTTP requests for MFA management.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { AppError } from "../../../shared/utils/AppError.js";
import { mfaService } from "./mfa.services.js";

import {
  disableMfaSchema,
  verifyMfaSchema,
} from "./mfa.validation.js";

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

export const mfaController = {
  /**
   * GET /api/auth/mfa/status
   */
  async status(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const status = await mfaService.getStatus(userId);

      res.status(200).json({
        message: "MFA status retrieved successfully.",
        data: status,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/auth/mfa/setup
   */
  async setup(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const result = await mfaService.beginSetup(userId);

      res.status(200).json({
        message: "MFA setup started.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/auth/mfa/verify
   */
  async verify(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const body = verifyMfaSchema.shape.body.parse(req.body);

      const result = await mfaService.verifySetup(userId, body);

      res.status(200).json({
        message: "MFA enabled successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * POST /api/auth/mfa/disable
   */
  async disable(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const userId = requireUserId(req, res);
      if (!userId) return;

      const body = disableMfaSchema.shape.body.parse(req.body);

      await mfaService.disable(userId, body);

      res.status(200).json({
        message: "MFA disabled successfully.",
      });
    } catch (error) {
      next(error);
    }
  },
};

