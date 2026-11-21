/**
 * File Name: analytics.routes.ts
 * Description: Authenticated productivity analytics routes.
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";

import { analyticsController } from "./analytics.controller.js";

const router = Router();

router.use(authenticate);

/** Headline numbers */
router.get("/overview", analyticsController.overview);
router.get("/daily", analyticsController.daily);
router.get("/monthly", analyticsController.monthly);
router.get("/completion-rate", analyticsController.completionRate);
router.get("/task-trends", analyticsController.taskTrends);
router.get("/overdue", analyticsController.overdue);
router.get("/productivity-summary", analyticsController.productivitySummary);

/** GET /api/analytics/weekly?weeks=8 */
router.get("/weekly", analyticsController.weekly);

/** GET /api/analytics/priority-suggestions?limit=20 */
router.get("/priority-suggestions", analyticsController.prioritySuggestions);

/** POST /api/analytics/priority-suggestions/apply */
router.post(
  "/priority-suggestions/apply",
  analyticsController.applyPrioritySuggestions,
);

export default router;
