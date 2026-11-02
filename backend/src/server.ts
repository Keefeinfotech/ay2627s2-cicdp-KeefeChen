/**
 * File Name: server.ts
 * Description: Application entry point responsible for
 *              environment validation, database connection,
 *              server startup and graceful shutdown.
 * Author: Keefe Chen
 */

import "dotenv/config";
import process from "node:process";
import app from "./app.js";
import { connectDatabase, disconnectDatabase } from "./config/database.js";
import {
  assertRuntimeEnv,
  EnvError,
  getPort,
} from "./config/environment.js";
import logger from "./config/logger.js";

const start = async (): Promise<void> => {
  // Validate environment configuration
  try {
    assertRuntimeEnv();
    logger.info("Runtime environment validated successfully");
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

  // Start Express server
  const port = getPort();

  const server = app.listen(port, () => {
    logger.info("Auxilia server started successfully", {
      port,
      environment: process.env.NODE_ENV || "development",
    });
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
