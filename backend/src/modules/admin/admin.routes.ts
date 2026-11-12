/**
 * File Name: admin.routes.ts
 * Description: Administrative API surface. Every route is behind the existing
 *              authenticate middleware and the role-based authorize guard, so
 *              only accounts with the `admin` role can reach any handler.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { authorize } from "../../middleware/authorize.js";
import { adminController } from "./admin.controller.js";

const router = Router();

router.use(authenticate, authorize("admin"));

router.get("/users", adminController.listUsers);
router.patch("/users/:id/status", adminController.setUserStatus);
router.get("/stats", adminController.getStats);

export default router;
