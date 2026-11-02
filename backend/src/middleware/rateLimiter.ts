import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import type { Request } from "express";
import {
  getAiRateLimitPerUser,
  getAuthRateLimitMax,
} from "../config/environment.js";
import {
  AI_RATE_LIMIT_WINDOW_MS,
  AUTH_RATE_LIMIT_WINDOW_MS,
} from "../constants/security.js";
import { logSecurityEvent } from "../shared/utils/securityLogger.js";

interface LimiterConfig {
  name: string;
  windowMs: number;
  limit: number;
  message: { error: string };
  keyGenerator?: (req: Request) => string;
}

export const createRateLimiter = (config: LimiterConfig) =>
  rateLimit({
    windowMs: config.windowMs,
    limit: config.limit,
    standardHeaders: true,
    legacyHeaders: false,
    message: config.message,
    ...(config.keyGenerator ? { keyGenerator: config.keyGenerator } : {}),
    handler: (req, res, _next, options) => {
      logSecurityEvent("rate_limit_exceeded", {
        requestId: req.requestId,
        userId: req.userId,
        ip: req.ip,
        path: req.path,
        limiter: config.name,
      });
      res.status(options.statusCode).json(options.message);
    },
  });

export const authRateLimiter = createRateLimiter({
  name: "auth",
  windowMs: AUTH_RATE_LIMIT_WINDOW_MS,
  limit: getAuthRateLimitMax(),
  message: { error: "Too many requests, please try again later." },
});

export const aiRateLimiter = createRateLimiter({
  name: "ai",
  windowMs: AI_RATE_LIMIT_WINDOW_MS,
  limit: getAiRateLimitPerUser(),
  message: { error: "Too many AI requests, please try again later." },
  keyGenerator: (req) => req.userId ?? ipKeyGenerator(req.ip ?? ""),
});
