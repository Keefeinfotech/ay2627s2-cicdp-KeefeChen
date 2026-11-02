/**
 * File Name: invitation.controller.ts
 * Description: Handles HTTP requests for group invitations.
 * Author: Keefe Chen
 */

import type {
  Request,
  Response,
  NextFunction,
} from "express";

import { InvitationService } from "./invitation.service.js";

const invitationService = new InvitationService();

/**
 * Extracts and validates the invitation ID from route parameters.
 */
function getInvitationId(req: Request): string {
  const invitationId = req.params.invitationId;

  if (typeof invitationId !== "string") {
    throw new Error("Invalid invitation ID.");
  }

  return invitationId;
}

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

export class InvitationController {
  /**
   * POST /api/invitations
   * Creates an invitation to join a group.
   */
  static create = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);

      const invitation = await invitationService.create(
        userId,
        req.body,
      );

      return res.status(201).json({
        message: "Invitation created successfully.",
        data: invitation,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * GET /api/invitations/:invitationId
   * Retrieves invitation details.
   */
  static get = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const invitationId = getInvitationId(req);

      const invitation = await invitationService.get(
        invitationId,
        userId,
      );

      return res.status(200).json({
        message: "Invitation retrieved successfully.",
        data: invitation,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * POST /api/invitations/accept
   * Accepts an invitation using its token.
   */
  static accept = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);

      const result = await invitationService.accept(
        userId,
        req.body,
      );

      return res.status(200).json({
        message: "Invitation accepted successfully.",
        data: result,
      });
    } catch (error) {
      return next(error);
    }
  };

  /**
   * DELETE /api/invitations/:invitationId
   * Cancels a pending invitation.
   */
  static cancel = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ) => {
    try {
      const userId = getAuthenticatedUserId(req);
      const invitationId = getInvitationId(req);

      const result = await invitationService.cancel(
        invitationId,
        userId,
      );

      return res.status(200).json({
        message: "Invitation cancelled successfully.",
        data: result,
      });
    } catch (error) {
      return next(error);
    }
  };
}