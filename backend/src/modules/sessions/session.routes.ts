/**
 * File Name: session.routes.ts
 * Description: Defines the group study session API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import {
  validateBody,
  validateRequest,
} from "../../middleware/validateRequest.js";
import { sessionController } from "./session.controller.js";

import {
  createSessionSchema,
  listSessionsSchema,
  sessionParamSchema,
  updateSessionSchema,
} from "./session.validation.js";

const router = Router({ mergeParams: true });

router.use(authenticate);

/**
 * GET /api/groups/:groupId/sessions
 */
router.get(
  "/",
  validateRequest(listSessionsSchema),
  sessionController.list,
);

/**
 * POST /api/groups/:groupId/sessions
 */
router.post(
  "/",
  validateBody(createSessionSchema),
  sessionController.create,
);

/**
 * POST /api/groups/:groupId/sessions/:sessionId/join
 */
router.post(
  "/:sessionId/join",
  validateRequest(sessionParamSchema),
  sessionController.join,
);

/**
 * POST /api/groups/:groupId/sessions/:sessionId/leave
 */
router.post(
  "/:sessionId/leave",
  validateRequest(sessionParamSchema),
  sessionController.leave,
);

/**
 * POST /api/groups/:groupId/sessions/:sessionId/cancel
 */
router.post(
  "/:sessionId/cancel",
  validateRequest(sessionParamSchema),
  sessionController.cancel,
);

/**
 * POST /api/groups/:groupId/sessions/:sessionId/complete
 */
router.post(
  "/:sessionId/complete",
  validateRequest(sessionParamSchema),
  sessionController.complete,
);

/**
 * PATCH /api/groups/:groupId/sessions/:sessionId
 */
router.patch(
  "/:sessionId",
  validateRequest(updateSessionSchema),
  sessionController.update,
);

/**
 * GET /api/groups/:groupId/sessions/:sessionId
 */
router.get(
  "/:sessionId",
  validateRequest(sessionParamSchema),
  sessionController.get,
);

/**
 * DELETE /api/groups/:groupId/sessions/:sessionId
 */
router.delete(
  "/:sessionId",
  validateRequest(sessionParamSchema),
  sessionController.remove,
);

export default router;
