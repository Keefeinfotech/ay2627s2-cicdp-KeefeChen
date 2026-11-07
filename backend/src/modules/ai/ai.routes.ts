import { Router } from "express";
import { authenticate } from "../../middleware/authenticate.js";
import { aiRateLimiter } from "../../middleware/rateLimiter.js";
import { validateRequest } from "../../middleware/validateRequest.js";
import { chat, taskDraft } from "./ai.controller.js";
import { chatSchema, taskDraftRequestSchema } from "./ai.validation.js";

const router = Router();

router.use((_req, res, next) => {
  res.setHeader("Cache-Control", "no-store");
  next();
});

router.post("/chat", authenticate, aiRateLimiter, validateRequest(chatSchema), chat);
router.post("/draft", authenticate, aiRateLimiter, validateRequest(taskDraftRequestSchema), taskDraft);

export default router;
