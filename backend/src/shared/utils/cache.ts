/**
 * File Name: cache.ts
 * Description: Minimal cache-aside helper on top of the optional shared
 *              Redis client. Every operation fails open: when Redis is
 *              unset or unreachable the caller simply computes the value
 *              and the request is served normally.
 * Author: Keefe Chen
 */

import { getRedisClient } from "../../config/redis.js";
import logger from "../../config/logger.js";

export const cacheGetJson = async <T>(key: string): Promise<T | null> => {
  const client = getRedisClient();
  if (!client) return null;

  try {
    const raw = await client.get(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch (error) {
    logger.warn("cache.get_failed", {
      key,
      error: error instanceof Error ? error.message : String(error),
    });
    return null;
  }
};

export const cacheSetJson = async (
  key: string,
  value: unknown,
  ttlSeconds: number,
): Promise<void> => {
  const client = getRedisClient();
  if (!client) return;

  try {
    await client.set(key, JSON.stringify(value), "EX", ttlSeconds);
  } catch (error) {
    logger.warn("cache.set_failed", {
      key,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

/** Deletes exact keys (best effort). */
export const cacheDel = async (...keys: string[]): Promise<void> => {
  const client = getRedisClient();
  if (!client || keys.length === 0) return;

  try {
    await client.del(...keys);
  } catch (error) {
    logger.warn("cache.del_failed", {
      keys,
      error: error instanceof Error ? error.message : String(error),
    });
  }
};

/** Deletes all keys matching a prefix pattern via SCAN (best effort). */
export const cacheDelByPattern = async (pattern: string): Promise<number> => {
  const client = getRedisClient();
  if (!client) return 0;

  try {
    let cursor = "0";
    let deleted = 0;

    do {
      const [next, keys] = await client.scan(cursor, "MATCH", pattern, "COUNT", 100);
      cursor = next;
      if (keys.length > 0) {
        await client.del(...keys);
        deleted += keys.length;
      }
    } while (cursor !== "0");

    return deleted;
  } catch (error) {
    logger.warn("cache.del_pattern_failed", {
      pattern,
      error: error instanceof Error ? error.message : String(error),
    });
    return 0;
  }
};
