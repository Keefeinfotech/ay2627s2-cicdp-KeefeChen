/**
 * File Name: progress.routes.ts
 * Description: Defines the group progress API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { progressController } from "./progress.controller.js";

const router = Router({ mergeParams: true });

router.use(authenticate);

/**
 * GET /api/groups/:groupId/progress
 */
router.get("/", progressController.get);

export default router;
