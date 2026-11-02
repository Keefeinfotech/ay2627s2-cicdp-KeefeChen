/**
 * File Name: user.controller.ts
 * Description: Handles HTTP requests for user profile operations.
 * Author: Keefe Chen
 */

import type {
  Request,
  Response,
  NextFunction,
} from "express";

import { userService } from "./user.service.js";

import type {
  UpdateOwnProfileBody,
  DeleteOwnAccountBody,
} from "./user.validation.js";

export const userController = {
  /**
   * GET /api/users/me
   *
   * Retrieves the authenticated user's profile.
   */
  async getOwnProfile(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = req.userId;

      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const user = await userService.getOwnProfile(userId);

      res.status(200).json({
        message: "User profile retrieved successfully.",
        data: user,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * PATCH /api/users/me
   *
   * Updates the authenticated user's profile.
   */
  async updateOwnProfile(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = req.userId;

      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const user = await userService.updateOwnProfile(
        userId,
        req.body as UpdateOwnProfileBody
      );

      res.status(200).json({
        message: "User profile updated successfully.",
        data: user,
      });
    } catch (error) {
      next(error);
    }
  },

  /**
   * DELETE /api/users/me
   *
   * Deactivates the authenticated user's account.
   * Requires current password confirmation.
   */
  async deleteOwnAccount(
    req: Request,
    res: Response,
    next: NextFunction
  ): Promise<void> {
    try {
      const userId = req.userId;

      if (!userId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      const { currentPassword } =
        req.body as DeleteOwnAccountBody;

      await userService.deleteOwnAccount(
        userId,
        currentPassword
      );

      res.status(200).json({
        message: "Your account has been deactivated successfully.",
      });
    } catch (error) {
      next(error);
    }
  },
};