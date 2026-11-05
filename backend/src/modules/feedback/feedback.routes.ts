import { Router } from "express";
import * as feedbackController from "./feedback.controller.js";
import { authenticate } from "../../middleware/authenticate.js";
import { authorize } from "../../middleware/authorize.js";
import { validateBody } from "../../middleware/validateRequest.js";
import {
  createFeedbackSchema,
  updateFeedbackStatusSchema,
} from "./feedback.validation.js";

const router = Router();

router.use(authenticate);

// User routes
router.post(
  "/",
  validateBody(createFeedbackSchema),
  feedbackController.createFeedback
);

router.get("/my", feedbackController.getMyFeedback);

// Admin routes
router.get(
  "/analytics/summary",
  authorize("ADMIN"),
  feedbackController.getFeedbackAnalytics
);

router.get(
  "/",
  authorize("ADMIN"),
  feedbackController.getAllFeedback
);

router.patch(
  "/:id/status",
  authorize("ADMIN"),
  validateBody(updateFeedbackStatusSchema),
  feedbackController.updateFeedbackStatus
);

router.post(
  "/:id/response",
  authorize("ADMIN"),
  feedbackController.respondToFeedback
);

// Shared owner / admin routes
router.get("/:id", feedbackController.getFeedbackById);
router.patch("/:id", feedbackController.updateFeedback);
router.delete("/:id", feedbackController.deleteFeedback);

export default router;