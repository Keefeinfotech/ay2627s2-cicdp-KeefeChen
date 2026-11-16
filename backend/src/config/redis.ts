/**
 * File Name: redis.ts
 * Description: Optional shared Redis client used for cross-instance state
 *              (rate-limit counters). When REDIS_URL is unset the backend
 *              keeps counters in process memory, which is correct for a
 *              single instance but limits the configured caps to each
 *              replica in a multi-instance deployment.
 *
 *              The client is created once and reused. It never blocks
 *              startup: it connects in the background, commands sent while
 *              disconnected fail immediately, and express-rate-limit is
 *              configured to pass the request on when its store errors
 *              (fail-open) rather than take the API down with Redis.
 * Author: Keefe Chen
 */

import Redis from "ioredis";
import logger from "./logger.js";
import { getRedisUrl } from "./environment.js";

const RECONNECT_DELAY_MS = 250;
const MAX_RECONNECT_DELAY_MS = 5_000;
// How often a connection error is logged to the app log. Throttled so a
// down Redis does not flood combined.log at the reconnect rate.
const ERROR_LOG_THROTTLE_MS = 30_000;

let client: Redis | null = null;
let lastErrorLogAt = 0;

export const getRedisClient = (): Redis | null => {
  const url = getRedisUrl();
  if (!url) return null;
  if (client) return client;

  client = new Redis(url, {
    lazyConnect: true,
    connectTimeout: 2_000,
    // Reject commands immediately instead of queuing them while
    // disconnected; express-rate-limit passes the request on when its
    // store throws (see `passOnStoreError` in middleware/rateLimiter.ts).
    enableOfflineQueue: false,
    maxRetriesPerRequest: 1,
    retryStrategy: (attempt) =>
      Math.min(attempt * RECONNECT_DELAY_MS, MAX_RECONNECT_DELAY_MS),
  });

  client.on("error", (error: Error) => {
    const now = Date.now();
    if (now - lastErrorLogAt < ERROR_LOG_THROTTLE_MS) return;
    lastErrorLogAt = now;
    logger.warn("redis.connection_error", {
      error: error.message,
      note: "rate limiter fails open; set or fix REDIS_URL",
    });
  });

  return client;
};

// Best-effort initial connect. Called at startup to warm the connection; a
// down Redis never blocks boot (limiters fail open) and recovers on their
// next successful script reload.
export const connectRedis = async (): Promise<void> => {
  const client = getRedisClient();
  if (!client) return;
  try {
    await client.connect();
  } catch (error) {
    logger.warn("redis.connect_failed", {
      error: error instanceof Error ? error.message : String(error),
      note: "rate limiter fails open until Redis is reachable",
    });
  }
};

export const closeRedisClient = async (): Promise<void> => {
  if (!client) return;
  const current = client;
  client = null;
  try {
    await current.quit();
  } catch {
    current.disconnect();
  }
};
