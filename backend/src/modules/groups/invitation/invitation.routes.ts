/**
 * File Name: invitation.routes.ts
 * Description: Defines API routes for group invitations.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { InvitationController } from "./invitation.controller";
import { validateRequest } from "../../../middleware/validateRequest.js";
import { authenticate } from "../../../middleware/authenticate";

import {
  createInvitationSchema,
  acceptInvitationSchema,
  invitationParamsSchema,
} from "./invitation.validation";

const router = Router();

/**
 * All invitation routes require authentication.
 */
router.use(authenticate);

/**
 * POST /api/invitations
 * Create an invitation to join a group.
 */
router.post(
  "/",
  validateRequest(createInvitationSchema),
  InvitationController.create,
);

/**
 * GET /api/invitations/:invitationId
 * Retrieve invitation details.
 */
router.get(
  "/:invitationId",
  validateRequest(invitationParamsSchema),
  InvitationController.get,
);

/**
 * POST /api/invitations/accept
 * Accept an invitation using its invitation token.
 */
router.post(
  "/accept",
  validateRequest(acceptInvitationSchema),
  InvitationController.accept,
);

/**
 * DELETE /api/invitations/:invitationId
 * Cancel a pending invitation.
 */
router.delete(
  "/:invitationId",
  validateRequest(invitationParamsSchema),
  InvitationController.cancel,
);

export default router;