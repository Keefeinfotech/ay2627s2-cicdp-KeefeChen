/**
 * File Name: reminder.routes.ts
 * Description: Reminder API routes (all authenticated, ownership-scoped).
 */

import { Router } from "express";
import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";
import { reminderController } from "./reminder.controller.js";
import {
  createReminderSchema,
  reminderIdParamSchema,
  reminderStatusSchema,
  updateReminderSchema,
  upcomingRemindersSchema,
} from "./reminder.validation.js";

const router = Router();

router.use(authenticate);

/** GET /api/reminders - list own reminders */
router.get("/", reminderController.index);

/** POST /api/reminders - create a reminder */
router.post(
  "/",
  validateRequest(createReminderSchema),
  reminderController.create,
);

/** GET /api/reminders/pending - pending reminders due now */
router.get("/pending", reminderController.pending);

/** GET /api/reminders/upcoming?days=7 - upcoming enabled reminders */
router.get(
  "/upcoming",
  validateRequest(upcomingRemindersSchema),
  reminderController.upcoming,
);

/** GET /api/reminders/:reminderId - single reminder (owner only) */
router.get(
  "/:reminderId",
  validateRequest(reminderIdParamSchema),
  reminderController.show,
);

/** PATCH /api/reminders/:reminderId - update reminder */
router.patch(
  "/:reminderId",
  validateRequest(updateReminderSchema),
  reminderController.update,
);

/** PATCH /api/reminders/:reminderId/status - enable/disable/complete toggle */
router.patch(
  "/:reminderId/status",
  validateRequest(reminderStatusSchema),
  reminderController.status,
);

/** POST /api/reminders/:reminderId/complete - mark completed */
router.post("/:reminderId/complete", reminderController.complete);

/** DELETE /api/reminders/:reminderId - delete */
router.delete("/:reminderId", reminderController.remove);

export default router;
