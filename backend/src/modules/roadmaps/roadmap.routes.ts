/**
 * File Name: roadmap.routes.ts
 * Description: Defines the group roadmap API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import {
  validateBody,
  validateRequest,
} from "../../middleware/validateRequest.js";
import { roadmapController } from "./roadmap.controller.js";

import {
  approveRoadmapSchema,
  createRoadmapSchema,
  listRoadmapsSchema,
  roadmapParamSchema,
  updateRoadmapItemSchema,
  updateRoadmapSchema,
} from "./roadmap.validation.js";

const router = Router({ mergeParams: true });

/**
 * All roadmap endpoints require authentication.
 * Group membership and role checks live in the service layer.
 */
router.use(authenticate);

/**
 * GET /api/groups/:groupId/roadmap
 */
router.get(
  "/",
  validateRequest(listRoadmapsSchema),
  roadmapController.list,
);

/**
 * POST /api/groups/:groupId/roadmap
 * Creates a roadmap for the group.
 */
router.post(
  "/",
  validateBody(createRoadmapSchema),
  roadmapController.create,
);

/**
 * PATCH /api/groups/:groupId/roadmap/:roadmapId/items/:itemId
 * Updates one item's status.
 */
router.patch(
  "/:roadmapId/items/:itemId",
  validateRequest(updateRoadmapItemSchema),
  roadmapController.updateItem,
);

/**
 * POST /api/groups/:groupId/roadmap/:roadmapId/approve
 */
router.post(
  "/:roadmapId/approve",
  validateRequest(approveRoadmapSchema),
  roadmapController.approve,
);

/**
 * PATCH /api/groups/:groupId/roadmap/:roadmapId
 */
router.patch(
  "/:roadmapId",
  validateRequest(updateRoadmapSchema),
  roadmapController.update,
);

/**
 * GET /api/groups/:groupId/roadmap/:roadmapId
 */
router.get(
  "/:roadmapId",
  validateRequest(roadmapParamSchema),
  roadmapController.get,
);

/**
 * DELETE /api/groups/:groupId/roadmap/:roadmapId
 */
router.delete(
  "/:roadmapId",
  validateRequest(roadmapParamSchema),
  roadmapController.remove,
);

export default router;
