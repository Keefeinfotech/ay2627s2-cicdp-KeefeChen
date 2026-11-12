/**
 * File Name: metrics.ts
 * Description: Prometheus instrumentation for the Auxilia backend. Exposes a
 *              protected /metrics endpoint, a low-cardinality HTTP request
 *              counter and latency histogram, the default Node/process
 *              metrics, and a database-connection health gauge.
 *
 *              The metrics endpoint is not public. Set METRICS_TOKEN to a
 *              strong random value and scrape with
 *              `Authorization: Bearer <token>`, or leave METRICS_TOKEN unset
 *              to require an authenticated administrator session.
 * Author: Keefe Chen
 */

import crypto from "node:crypto";
import type { NextFunction, Request, Response } from "express";
import mongoose from "mongoose";
import client from "prom-client";

import { authenticate } from "../../middleware/authenticate.js";
import { authorize } from "../../middleware/authorize.js";
import { unauthorized } from "../../shared/utils/AppError.js";

// ---------------------------------------------------------------------------
// Metric definitions
// ---------------------------------------------------------------------------

const PREFIX = "auxilia_";

// Node/process default metrics (cpu, memory, GC, event loop lag, ...).
client.collectDefaultMetrics({ prefix: PREFIX });

export const httpRequestsTotal = new client.Counter({
  name: `${PREFIX}http_requests_total`,
  help: "Total HTTP requests handled, labelled by method, route template and status code.",
  labelNames: ["method", "route", "status_code"],
});

export const httpRequestDuration = new client.Histogram({
  name: `${PREFIX}http_request_duration_seconds`,
  help: "HTTP request duration in seconds, labelled by method, route template and status code.",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10],
});

export const dbConnected = new client.Gauge({
  name: `${PREFIX}db_connected`,
  help: "MongoDB connection state: 1 when connected, 0 otherwise.",
});

// ---------------------------------------------------------------------------
// Path normalisation (keeps label cardinality bounded)
// ---------------------------------------------------------------------------

const OBJECT_ID_RE = /\b[0-9a-f]{24}\b/gi;
const UUID_RE =
  /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi;
const NUMERIC_RE = /\b\d+\b/g;

const normalizePath = (path: string): string => {
  const normalized = path
    .split("?")[0]
    .replace(UUID_RE, ":id")
    .replace(OBJECT_ID_RE, ":id")
    .replace(NUMERIC_RE, ":n")
    .slice(0, 120);
  return normalized.length === 0 ? "/" : normalized;
};

/** Timing middleware mounted before the routers so every request is timed. */
export const metricsMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const end = httpRequestDuration.startTimer();
  res.on("finish", () => {
    const route = normalizePath(req.originalUrl || req.url || "/");
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode),
    };
    httpRequestsTotal.inc(labels);
    end(labels);
  });
  next();
};

// ---------------------------------------------------------------------------
// /metrics endpoint
// ---------------------------------------------------------------------------

const bearerEquals = (provided: string, expected: string): boolean => {
  const a = Buffer.from(provided);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
};

/**
 * Auth guard for /metrics. Prefers a static METRICS_TOKEN (kept outside git,
 * shared with the Prometheus scrape job). Falls back to an authenticated
 * administrator session so the metrics are never anonymous.
 */
export const metricsGuard = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const token = process.env.METRICS_TOKEN?.trim();
  if (token) {
    const header = req.headers.authorization ?? "";
    const provided = header.startsWith("Bearer ") ? header.slice(7).trim() : "";
    if (provided && bearerEquals(provided, token)) {
      next();
      return;
    }
    next(unauthorized("Metrics access token required"));
    return;
  }

  // Authenticate is promise-based; we handle failures through the callback
  // and intentionally do not await the outer promise.
  void authenticate(req, res, (err?: unknown) => {
    if (err) {
      next(err);
      return;
    }
    authorize("admin")(req, res, next);
  });
};

/** Renders the Prometheus exposition format. */
export const metricsHandler = async (
  _req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    dbConnected.set(mongoose.connection.readyState === 1 ? 1 : 0);
    res.set("Content-Type", client.register.contentType);
    res.set("Cache-Control", "no-store");
    res.send(await client.register.metrics());
  } catch (error) {
    next(error);
  }
};
