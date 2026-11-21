/**
 * File Name: assistant.routes.ts
 * Description: Assistant endpoints (interpret → clarify → preview → confirm/cancel).
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { aiRateLimiter } from "../../middleware/rateLimiter.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { assistantController } from "./assistant.controller.js";
import {
  cancelSchema,
  clarifySchema,
  confirmSchema,
  interpretSchema,
  previewSchema,
  suggestionsSchema,
} from "./assistant.validation.js";

const router = Router();

router.use(authenticate);
router.use((_req, res, next) => {
  res.setHeader("Cache-Control", "no-store");
  next();
});

router.post(
  "/interpret",
  aiRateLimiter,
  validateRequest(interpretSchema),
  assistantController.interpret,
);
router.post(
  "/clarify",
  aiRateLimiter,
  validateRequest(clarifySchema),
  assistantController.clarify,
);
router.post(
  "/preview",
  validateRequest(previewSchema),
  assistantController.preview,
);
router.post(
  "/confirm",
  validateRequest(confirmSchema),
  assistantController.confirm,
);
router.post(
  "/cancel",
  validateRequest(cancelSchema),
  assistantController.cancel,
);
router.post(
  "/suggestions",
  validateRequest(suggestionsSchema),
  assistantController.suggestions,
);

export default router;
