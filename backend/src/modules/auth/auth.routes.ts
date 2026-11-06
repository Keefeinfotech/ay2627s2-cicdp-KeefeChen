import { Router } from "express";
import { requireCaptcha } from "../../middleware/captcha.js";
import { authRateLimiter } from "../../middleware/rateLimiter.js";
import { validateRequest } from "../../middleware/validateRequest.js";
import { authenticate } from "../../middleware/authenticate.js";
import { login, logout, me, signup } from "./auth.controller.js";
import { loginSchema, signupSchema } from "./auth.validation.js";

const router = Router();

router.post(
  "/signup",
  authRateLimiter,
  requireCaptcha,
  validateRequest(signupSchema),
  signup
);
router.post(
  "/login",
  authRateLimiter,
  requireCaptcha,
  validateRequest(loginSchema),
  login
);

router.get("/me", authenticate, me);
router.post("/logout", authenticate, logout);

export default router;
