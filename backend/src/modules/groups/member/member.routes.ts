/**
 * File Name: member.routes.ts
 * Description: Defines API routes for group member listings.
 */

import { Router } from "express";

import { MemberController } from "./member.controller.js";
import { authenticate } from "../../../middleware/authenticate.js";

const router = Router({ mergeParams: true });

router.use(authenticate);

// GET /api/groups/:groupId/members
router.get("/", MemberController.list);

export default router;
