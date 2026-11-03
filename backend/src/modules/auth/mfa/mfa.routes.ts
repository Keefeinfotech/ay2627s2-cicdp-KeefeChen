/**
 * File Name: mfa.routes.ts
 * Description: Defines the MFA API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../../middleware/authenticate.js";
import { validateBody } from "../../../middleware/validateRequest.js";
import { mfaController } from "./mfa.controller.js";

import {
  disableMfaSchema,
  verifyMfaSchema,
} from "./mfa.validation.js";

const router = Router();

router.use(authenticate);

/**
 * GET /api/auth/mfa/status
 */
router.get("/status", mfaController.status);

/**
 * POST /api/auth/mfa/setup
 */
router.post("/setup", mfaController.setup);

/**
 * POST /api/auth/mfa/verify
 */
router.post(
  "/verify",
  validateBody(verifyMfaSchema),
  mfaController.verify,
);

/**
 * POST /api/auth/mfa/disable
 */
router.post(
  "/disable",
  validateBody(disableMfaSchema),
  mfaController.disable,
);

export default router;
