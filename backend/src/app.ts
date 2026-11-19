/**
 * File Name: app.ts
 * Description: Configures the Express application, security middleware,
 *              API routes, rate limiting, and error handling.
 * Author: Keefe Chen
 */

import express from "express";
import cors from "cors";

import { swaggerDocument, swaggerUi } from "./config/swagger.js";
import { isProduction, shouldTrustProxy } from "./config/environment.js";

import {
  corsOptions,
  helmetMiddleware,
  jsonBodyOptions,
  urlEncodedBodyOptions,
} from "./config/security.js";

import { errorHandler } from "./middleware/errorHandler.js";
import { notFound } from "./middleware/notFound.js";
import { requestId } from "./middleware/requestId.js";
import {
  apiRateLimiter,
  metricsRateLimiter,
} from "./middleware/rateLimiter.js";

import authRoutes from "./modules/auth/auth.routes.js";
import aiRoutes from "./modules/ai/ai.routes.js";
import healthRoutes from "./modules/health/health.routes.js";
import userRoutes from "./modules/users/user.routes.js";
import taskRoutes from "./modules/tasks/task.routes.js";
import groupRoutes from "./modules/groups/index.js";
import invitationRoutes from "./modules/groups/invitation/invitation.routes.js";
import auditRoutes from "./modules/audit/audit.routes.js";
import roadmapRoutes from "./modules/roadmaps/roadmap.routes.js";
import rubricRoutes from "./modules/rubrics/rubric.routes.js";
import feedbackRoutes from "./modules/feedback/feedback.routes.js";
import sessionRoutes from "./modules/sessions/session.routes.js";
import progressRoutes from "./modules/progress/progress.routes.js";
import calendarRoutes from "./modules/calendar/calendar.routes.js";
import syncRoutes from "./modules/sync/index.js";
import reminderRoutes from "./modules/reminders/reminder.routes.js";
import adminRoutes from "./modules/admin/admin.routes.js";
import analyticsRoutes from "./modules/analytics/analytics.routes.js";
import {
  metricsMiddleware,
  metricsGuard,
  metricsHandler,
} from "./modules/metrics/metrics.js";

const app = express();

// --------------------------------------------------
// 1. Core Server & Proxy Configuration
// --------------------------------------------------

// Disable Express identification headers.
app.disable("x-powered-by");

// Escape JSON responses.
app.set("json escape", true);

// Trust the configured reverse proxy.
if (shouldTrustProxy()) {
  app.set("trust proxy", 1);
}

// --------------------------------------------------
// 2. Security & Request Middleware
// --------------------------------------------------

app.use(requestId);
app.use(metricsMiddleware);
app.use(helmetMiddleware);
app.use(cors(corsOptions));

app.use(express.json(jsonBodyOptions));
app.use(express.urlencoded(urlEncodedBodyOptions));

// Apply API rate limiting.
app.use("/api", apiRateLimiter);

// --------------------------------------------------
// 3. Root & API Information Endpoints
// --------------------------------------------------

// Root endpoint for Render deployment verification.
app.get("/", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "Auxilia Backend API is running.",
    documentation: "/api-docs",
    health: "/api/health",
    versionedHealth: "/api/v1/health",
  });
});

// API information endpoint. Reports supported API versions.
app.get(["/api", "/api/v1"], (_req, res) => {
  res.status(200).json({
    success: true,
    message: "Welcome to the Auxilia API.",
    version: "v1",
    versions: {
      v1: "/api/v1",
      legacy: "/api",
    },
    health: "/api/v1/health",
  });
});

// --------------------------------------------------
// 4. API Documentation
// --------------------------------------------------

if (!isProduction()) {
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));
}

// --------------------------------------------------
// 5. Health & Authentication Routes
// --------------------------------------------------

// All application routes live on a shared router that is mounted at both
// /api (legacy, unversioned) and /api/v1 (canonical). New clients should
// use /api/v1; the legacy mount is retained for backward compatibility.
const apiRouter = express.Router();

apiRouter.use("/health", healthRoutes);

apiRouter.use(
  "/auth",
  (_req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    next();
  },
  authRoutes,
);

// --------------------------------------------------
// 6. Application API Routes
// --------------------------------------------------

apiRouter.use("/ai", aiRoutes);

apiRouter.use("/users", userRoutes);
apiRouter.use("/tasks", taskRoutes);

// Nested group resource routes.
apiRouter.use("/groups/:groupId/roadmap", roadmapRoutes);
apiRouter.use("/groups/:groupId/rubrics", rubricRoutes);
apiRouter.use("/groups/:groupId/sessions", sessionRoutes);
apiRouter.use("/groups/:groupId/progress", progressRoutes);
apiRouter.use("/groups/:groupId/audit", auditRoutes);

// General group and invitation routes.
apiRouter.use("/groups", groupRoutes);
apiRouter.use("/invitations", invitationRoutes);

apiRouter.use("/feedback", feedbackRoutes);
apiRouter.use("/calendar", calendarRoutes);
apiRouter.use("/reminders", reminderRoutes);
apiRouter.use("/sync", syncRoutes);
apiRouter.use("/admin", adminRoutes);
apiRouter.use("/analytics", analyticsRoutes);

// Mount the shared router at the canonical versioned prefix and the legacy one.
app.use("/api/v1", apiRouter);
app.use("/api", apiRouter);
// Protected Prometheus metrics — outside the /api rate limiter so scrape
// intervals are not throttled, and guarded by METRICS_TOKEN or admin auth.
app.get("/metrics", metricsRateLimiter, metricsGuard, metricsHandler);

// --------------------------------------------------
// 7. Global Error Handling
// --------------------------------------------------

// Handle requests that do not match registered routes.
app.use(notFound);

// Handle application errors.
app.use(errorHandler);

export default app;
