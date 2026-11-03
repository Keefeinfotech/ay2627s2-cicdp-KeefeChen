/**
 * File Name: audit.routes.ts
 * Description: Defines the group activity trail API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { auditController } from "./audit.controller.js";

const router = Router({ mergeParams: true });

/**
 * All audit endpoints require authentication and group membership.
 * Membership is enforced by the service layer.
 */
router.use(authenticate);

/**
 * GET /api/groups/:groupId/audit
 * Retrieves the paginated activity trail for a group.
 */
router.get("/", auditController.list);

export default router;
