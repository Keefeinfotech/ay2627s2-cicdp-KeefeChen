import type { NextFunction, Request, Response } from "express";
import { isCaptchaEnabled, verifyTurnstileToken } from "../shared/utils/captcha.js";
import { logSecurityEvent } from "../shared/utils/securityLogger.js";

export const requireCaptcha = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  if (!isCaptchaEnabled()) {
    next();
    return;
  }

  if (!process.env.TURNSTILE_SECRET_KEY?.trim()) {
    res.status(503).json({
      error: "CAPTCHA is enabled but not configured",
      code: "CAPTCHA_NOT_CONFIGURED",
    });
    return;
  }

  const headerToken = req.headers["x-captcha-token"];
  const token =
    (typeof headerToken === "string" ? headerToken : undefined) ||
    (typeof req.body?.captchaToken === "string" ? req.body.captchaToken : "");

  if (!token) {
    res.status(400).json({
      error: "CAPTCHA verification is required",
      code: "CAPTCHA_REQUIRED",
    });
    return;
  }

  const result = await verifyTurnstileToken(token, req.ip);
  if (!result.success) {
    logSecurityEvent("captcha_rejected", {
      requestId: req.requestId,
      ip: req.ip,
      path: req.path,
      reason: result.reason,
    });
    res.status(400).json({
      error: "CAPTCHA verification failed",
      code: "CAPTCHA_FAILED",
    });
    return;
  }

  next();
};
