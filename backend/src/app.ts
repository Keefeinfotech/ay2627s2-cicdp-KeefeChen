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
import mfaRoutes from "./modules/auth/mfa/mfa.routes.js";
import syncRoutes from "./modules/sync/sync.routes.js";

const app = express();

// --------------------------------------------------
// 1. Core Server & Proxy Configuration
// --------------------------------------------------

// Disable identity headers
app.disable("x-powered-by");
app.set("json escape", true);

if (shouldTrustProxy()) {
  app.set("trust proxy", 1);
}

app.use(requestId);
app.use(helmetMiddleware);
app.use(cors(corsOptions));
app.use(express.json(jsonBodyOptions));
app.use(express.urlencoded(urlEncodedBodyOptions));

if (!isProduction()) {
  app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerDocument));
}

app.use("/api/health", healthRoutes);
app.use(
  "/api/auth",
  (_req, res, next) => {
    res.setHeader("Cache-Control", "no-store");
    next();
  },
  authRoutes
);
app.use("/api/auth/mfa", mfaRoutes);
app.use("/api/ai", aiRoutes);

app.use("/api/users", userRoutes);
app.use("/api/tasks", taskRoutes);
app.use("/api/groups", groupRoutes);
app.use("/api/invitations", invitationRoutes);

// Nested resource sub-routes under /api/groups
app.use("/api/groups/:groupId/roadmap", roadmapRoutes);
app.use("/api/groups/:groupId/rubrics", rubricRoutes);
app.use("/api/groups/:groupId/sessions", sessionRoutes);
app.use("/api/groups/:groupId/progress", progressRoutes);
app.use("/api/groups/:groupId/audit", auditRoutes);

app.use("/api/feedback", feedbackRoutes);
app.use("/api/calendar", calendarRoutes);
app.use("/api/sync", syncRoutes);

// --------------------------------------------------
// 7. Global Error Handling
// --------------------------------------------------

app.use(notFound);
app.use(errorHandler);

export default app;
