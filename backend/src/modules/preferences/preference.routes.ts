/**
 * File Name: preference.routes.ts
 * Description: User preferences routes.
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { preferenceController } from "./preference.controller.js";
import {
  updateAppearancePreferencesSchema,
  updateNotificationPreferencesSchema,
  updatePreferencesSchema,
  updateTimezoneSchema,
} from "./preference.validation.js";

const router = Router();

router.use(authenticate);

router.get("/", preferenceController.get);
router.patch(
  "/",
  validateRequest(updatePreferencesSchema),
  preferenceController.update,
);
router.patch(
  "/notifications",
  validateRequest(updateNotificationPreferencesSchema),
  preferenceController.updateNotifications,
);
router.patch(
  "/appearance",
  validateRequest(updateAppearancePreferencesSchema),
  preferenceController.updateAppearance,
);
router.patch(
  "/timezone",
  validateRequest(updateTimezoneSchema),
  preferenceController.updateTimezone,
);

export default router;
