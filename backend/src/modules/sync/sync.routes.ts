/**
 * File Name: sync.routes.ts
 * Description: Defines the change-feed API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { syncController } from "./sync.controller.js";

const router = Router();

router.use(authenticate);

/**
 * GET /api/sync/changes
 */
router.get("/changes", syncController.changes);

export default router;
