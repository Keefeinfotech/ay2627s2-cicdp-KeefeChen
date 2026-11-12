import { Router } from "express";
import { requireCaptcha } from "../../middleware/captcha.js";
import { authRateLimiter } from "../../middleware/rateLimiter.js";
import { validateRequest } from "../../middleware/validateRequest.js";
import { authenticate } from "../../middleware/authenticate.js";
import {
  forgotPassword,
  listSessions,
  login,
  logout,
  me,
  refresh,
  resetPassword,
  revokeSession,
  signup,
} from "./auth.controller.js";
import {
  forgotPasswordSchema,
  loginSchema,
  refreshSchema,
  resetPasswordSchema,
  signupSchema,
} from "./auth.validation.js";

const router = Router();

router.post(
  "/signup",
  authRateLimiter,
  requireCaptcha,
  validateRequest(signupSchema),
  signup,
);
router.post(
  "/login",
  authRateLimiter,
  requireCaptcha,
  validateRequest(loginSchema),
  login,
);
router.post(
  "/refresh",
  authRateLimiter,
  validateRequest(refreshSchema),
  refresh,
);
router.post(
  "/forgot-password",
  authRateLimiter,
  requireCaptcha,
  validateRequest(forgotPasswordSchema),
  forgotPassword,
);
router.post(
  "/reset-password",
  authRateLimiter,
  validateRequest(resetPasswordSchema),
  resetPassword,
);

router.get("/me", authenticate, me);
router.post("/logout", authenticate, logout);
router.get("/sessions", authenticate, listSessions);
router.delete("/sessions/:id", authenticate, revokeSession);

export default router;
