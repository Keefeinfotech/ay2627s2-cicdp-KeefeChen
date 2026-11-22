import type { Request, Response } from "express";
import mongoose from "mongoose";

import { getRedisClient } from "../../config/redis.js";
import { getRedisUrl } from "../../config/environment.js";

export const healthCheck = (_req: Request, res: Response): void => {
  res.status(200).json({
    status: "ok",
    service: "auxilia-api",
  });
};

/**
 * Liveness: the process is up and the event loop is responsive enough to
 * answer. No dependency details leak here.
 */
export const livenessCheck = (_req: Request, res: Response): void => {
  res.status(200).json({ status: "ok" });
};

/**
 * Readiness: the service can actually serve traffic (database reachable).
 * Returns 503 with a minimal, non-sensitive reason when it cannot.
 */
export const readinessCheck = async (
  _req: Request,
  res: Response,
): Promise<void> => {
  const mongoReady = mongoose.connection.readyState === 1;

  let redis: "ok" | "unavailable" | "not_configured" = "not_configured";
  if (getRedisUrl()) {
    const client = getRedisClient();
    if (client) {
      try {
        await client.ping();
        redis = "ok";
      } catch {
        redis = "unavailable";
      }
    } else {
      redis = "unavailable";
    }
  }

  const ready = mongoReady;

  res.status(ready ? 200 : 503).json({
    status: ready ? "ready" : "not_ready",
    checks: {
      mongodb: mongoReady ? "ok" : "unavailable",
      redis,
    },
  });
};
