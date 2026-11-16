/**
 * File Name: server.ts
 * Description: Application entry point responsible for
 *              environment validation, database connection,
 *              server startup and graceful shutdown.
 * Author: Keefe Chen
 */

import "dotenv/config";
import process from "node:process";
import type { Express } from "express";
import { connectDatabase, disconnectDatabase } from "./config/database.js";
import {
  assertRuntimeEnv,
  EnvError,
  getPort,
  isProduction,
  isRateLimitRedisEnabled,
} from "./config/environment.js";
import { connectRedis, closeRedisClient } from "./config/redis.js";
import logger from "./config/logger.js";

const start = async (): Promise<void> => {
  // Validate environment configuration
  try {
    assertRuntimeEnv();
    if (isProduction() && !isRateLimitRedisEnabled()) {
      logger.warn(
        "REDIS_URL is not set; rate-limit counters are kept in this process and each replica enforces its own cap. Set REDIS_URL (shared Redis) for consistent limits across instances.",
      );
    }
    logger.info("Runtime environment validated successfully");
    // Connect to Redis (if configured) before importing the app so the
    // rate limiter loads its scripts against a healthy connection. Fails open.
    await connectRedis();
  } catch (err) {
    const message =
      err instanceof EnvError ? err.message : "Invalid configuration";

    logger.error("Application startup failed: Invalid configuration", {
      error: message,
    });

    process.exit(1);
  }

  // Establish database connection
  try {
    await connectDatabase();
    logger.info("Database connection established successfully");
  } catch (err) {
    logger.error("Database connection failed", {
      error: err instanceof Error ? err.message : "Unknown database error",
    });

    process.exit(1);
  }

  // Render (and most PaaS platforms) inject PORT and probe the service on it.
  // Binding to 0.0.0.0 instead of the unspecified IPv6 address keeps IPv4
  // health checks and port scans reachable regardless of dual-stack support.
  // Imported here (not statically) so rate-limit stores are created after
  // the best-effort Redis connect above. The explicit type is needed because
  // NodeNext reports the CJS-emitted namespace for the dynamic import.
  const { default: app } = (await import("./app.js")) as unknown as {
    default: Express;
  };

  const port = getPort();
  const host = "0.0.0.0";

  const server = app.listen(port, host, () => {
    logger.info("Auxilia server started successfully", {
      host,
      port,
      environment: process.env.NODE_ENV || "development",
    });
  });

  // Surface bind failures (EADDRINUSE, EACCES, ...) as a logged, non-zero
  // exit instead of an unhandled 'error' event crashing the process.
  server.on("error", (err: NodeJS.ErrnoException) => {
    logger.error("Application startup failed: port binding error", {
      error: err.message,
      code: err.code,
      host,
      port,
    });

    process.exit(1);
  });

  let shuttingDown = false;

  // Handle graceful server shutdown
  const shutdown = (signal: string): void => {
    if (shuttingDown) return;

    shuttingDown = true;

    logger.info("Graceful shutdown initiated", { signal });

    const forceExit = setTimeout(() => {
      logger.error("Forced application shutdown after timeout");
      process.exit(1);
    }, 10_000);

    forceExit.unref();

    server.close(() => {
      void disconnectDatabase()
        .then(() => closeRedisClient())
        .then(() => {
          logger.info("Database disconnected successfully");
          logger.info("Application shutdown completed");

          clearTimeout(forceExit);
          process.exit(0);
        })
        .catch((err: unknown) => {
          logger.error("Error during database disconnection", {
            error: err instanceof Error ? err.message : String(err),
          });

          clearTimeout(forceExit);
          process.exit(1);
        });
    });
  };

  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
};

void start();
