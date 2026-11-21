/**
 * File Name: queue.ts
 * Description: Minimal in-process background job queue. A stepping stone
 *              towards a brokered solution (e.g. RabbitMQ): jobs are
 *              registered by name, enqueued from request handlers, and
 *              processed asynchronously in FIFO order. Errors are logged and
 *              counted, never thrown back into the request path.
 *
 *              Limitations (by design, for now): no persistence across
 *              restarts, no retries, single-process only.
 * Author: Keefe Chen
 */

import logger from "../../config/logger.js";

export type JobHandler<T = unknown> = (payload: T) => Promise<void>;

interface QueuedJob {
  name: string;
  payload: unknown;
  enqueuedAt: number;
}

const handlers = new Map<string, JobHandler>();
const backlog: QueuedJob[] = [];
let processing = false;

const stats = {
  enqueued: 0,
  completed: 0,
  failed: 0,
};

export const registerJob = <T>(name: string, handler: JobHandler<T>): void => {
  handlers.set(name, handler as JobHandler);
};

export const enqueue = (name: string, payload: unknown): boolean => {
  if (!handlers.has(name)) {
    logger.warn("job.unknown", { name });
    return false;
  }

  backlog.push({ name, payload, enqueuedAt: Date.now() });
  stats.enqueued += 1;

  // Kick the drain loop asynchronously; never block the caller.
  setImmediate(() => {
    void drain();
  });

  return true;
};

const drain = async (): Promise<void> => {
  if (processing) return;
  processing = true;

  while (backlog.length > 0) {
    const job = backlog.shift();
    if (!job) continue;

    const handler = handlers.get(job.name);
    if (!handler) continue;

    try {
      await handler(job.payload);
      stats.completed += 1;
    } catch (error) {
      stats.failed += 1;
      logger.error("job.failed", {
        name: job.name,
        latencyMs: Date.now() - job.enqueuedAt,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  processing = false;
};

export const getJobStats = () => ({ ...stats, pending: backlog.length });
