/**
 * File Name: reminder.routes.ts
 * Description: Defines the reminder API routes.
 * Author: Keefe Chen
 */

import { Router } from "express";
import {
  authenticate,
} from "../../middleware/authenticate.js";
import {
  reminderController,
} from "./reminder.controller.js";

const router = Router();

router.use(authenticate);

/**
 * GET /api/reminders - Get all reminders for authenticated user
 */
router.get("/", reminderController.index);

/**
 * POST /api/reminders - Create a new reminder
 */
router.post("/", reminderController.create);

/**
 * POST /api/reminders/:id/complete - Mark reminder as completed
 */
router.post("/:id/complete", reminderController.complete);

/**
 * DELETE /api/reminders/:id - Delete a reminder
 */
router.delete("/:id", reminderController.remove);

/**
 * GET /api/reminders/pending - Get pending reminders due now
 */
router.get("/pending", reminderController.pending);

export default router;