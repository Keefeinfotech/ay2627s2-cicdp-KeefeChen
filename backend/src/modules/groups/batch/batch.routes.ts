/**
 * File Name: batch.routes.ts
 * Description: Defines the bulk membership API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../../middleware/authenticate.js";
import { validateBody } from "../../../middleware/validateRequest.js";
import { createRateLimiter } from "../../../middleware/rateLimiter.js";
import { batchController } from "./batch.controller.js";
import { batchAddMembersSchema } from "./batch.validation.js";

/**
 * Heavy batch calls get a stricter limit than normal API traffic.
 */
const batchRateLimiter = createRateLimiter({
  name: "batch",
  windowMs: 60 * 1000,
  limit: 10,
  message: { error: "Too many batch requests, please try again later." },
});

const router = Router({ mergeParams: true });

router.use(authenticate);

/**
 * POST /api/groups/:groupId/members/batch
 */
router.post(
  "/",
  batchRateLimiter,
  validateBody(batchAddMembersSchema),
  batchController.addMembers,
);

export default router;
