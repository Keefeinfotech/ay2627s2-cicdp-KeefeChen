/**
 * File Name: user.routes.ts
 * Description: Defines authenticated user profile API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { userController } from "./user.controller.js";
import {
  updateOwnProfileSchema,
  updateOwnEmailSchema,
} from "./user.validation.js";

const router = Router();

/**
 * All user profile routes require authentication.
 */
router.use(authenticate);

/**
 * GET /api/users/me
 * Retrieves the currently authenticated user's profile.
 */
router.get("/me", userController.getOwnProfile);

/**
 * PATCH /api/users/me
 * Updates the currently authenticated user's profile.
 */
router.patch(
  "/me",
  validateRequest(updateOwnProfileSchema),
  userController.updateOwnProfile,
);

/**
 * PATCH /api/users/me/email
 * Changes the authenticated user's email address.
 */
router.patch(
  "/me/email",
  validateRequest(updateOwnEmailSchema),
  userController.updateOwnEmail,
);

/**
 * DELETE /api/users/me
 * Deletes or deactivates the currently authenticated user's account.
 */
router.delete("/me", userController.deleteOwnAccount);

export default router;
