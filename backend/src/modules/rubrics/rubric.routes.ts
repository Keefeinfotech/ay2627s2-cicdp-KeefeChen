/**
 * File Name: rubric.routes.ts
 * Description: Defines the group rubric API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import {
  validateBody,
  validateRequest,
} from "../../middleware/validateRequest.js";
import { createRateLimiter } from "../../middleware/rateLimiter.js";
import { rubricController } from "./rubric.controller.js";

import {
  listRubricsSchema,
  parseRubricSchema,
  rubricParamSchema,
  rubricRoadmapProposalSchema,
} from "./rubric.validation.js";

/**
 * Parsing is text-heavy, so it has its own modest rate limit.
 */
const rubricRateLimiter = createRateLimiter({
  name: "rubrics",
  windowMs: 60 * 1000,
  limit: 30,
  message: { error: "Too many rubric requests, please try again later." },
});

const router = Router({ mergeParams: true });

router.use(authenticate);

/**
 * POST /api/groups/:groupId/rubrics/parse
 */
router.post(
  "/parse",
  rubricRateLimiter,
  validateBody(parseRubricSchema),
  rubricController.create,
);

/**
 * GET /api/groups/:groupId/rubrics
 */
router.get(
  "/",
  validateRequest(listRubricsSchema),
  rubricController.list,
);

/**
 * POST /api/groups/:groupId/rubrics/:rubricId/roadmap-proposals
 */
router.post(
  "/:rubricId/roadmap-proposals",
  validateRequest(rubricRoadmapProposalSchema),
  rubricController.createRoadmapProposal,
);

/**
 * GET /api/groups/:groupId/rubrics/:rubricId
 */
router.get(
  "/:rubricId",
  validateRequest(rubricParamSchema),
  rubricController.get,
);

/**
 * DELETE /api/groups/:groupId/rubrics/:rubricId
 */
router.delete(
  "/:rubricId",
  validateRequest(rubricParamSchema),
  rubricController.remove,
);

export default router;
