import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import type { Request } from "express";
import {
  getAiRateLimitPerUser,
  getApiRateLimitMax,
  getAuthRateLimitMax,
} from "../config/environment.js";
import {
  AI_RATE_LIMIT_WINDOW_MS,
  API_RATE_LIMIT_WINDOW_MS,
  AUTH_RATE_LIMIT_WINDOW_MS,
} from "../constants/security.js";
import { logSecurityEvent } from "../shared/utils/securityLogger.js";

interface LimiterConfig {
  name: string;
  windowMs: number;
  limit: number;
  message: { error: string };
  keyGenerator?: (req: Request) => string;
  skip?: (req: Request) => boolean;
}

export const createRateLimiter = (config: LimiterConfig) =>
  rateLimit({
    windowMs: config.windowMs,
    limit: config.limit,
    standardHeaders: true,
    legacyHeaders: false,
    message: config.message,
    ...(config.keyGenerator ? { keyGenerator: config.keyGenerator } : {}),
    ...(config.skip ? { skip: config.skip } : {}),
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

// Dedicated limiter for the /metrics scrape endpoint. Generous on purpose:
// a 10s scrape interval is ~6 requests/min, so 120/min leaves ample headroom
// while still bounding abuse of the authenticated metrics surface.
const METRICS_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const METRICS_RATE_LIMIT_MAX = 120;
export const metricsRateLimiter = createRateLimiter({
  name: "metrics",
  windowMs: METRICS_RATE_LIMIT_WINDOW_MS,
  limit: METRICS_RATE_LIMIT_MAX,
  message: { error: "Too many requests, please try again later." },
  keyGenerator: (req) => ipKeyGenerator(req.ip ?? ""),
});

// Baseline limiter for the whole API. Authorization is cheap, but every route
// handler still needs a baseline because it runs after authentication; mounted
// before the routers so it covers handlers grouped under /api. The skip keeps
// the unit/integration suite fast and deterministic (NODE_ENV=test).
export const apiRateLimiter = createRateLimiter({
  name: "api",
  windowMs: API_RATE_LIMIT_WINDOW_MS,
  limit: getApiRateLimitMax(),
  message: { error: "Too many requests, please try again later." },
  keyGenerator: (req) => req.userId ?? ipKeyGenerator(req.ip ?? ""),
  skip: () => process.env.NODE_ENV === "test",
});
