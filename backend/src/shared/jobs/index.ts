/**
 * File Name: jobs/index.ts
 * Description: Registers built-in background jobs. Imported once at server
 *              startup (see server.ts) so handlers are available before any
 *              request enqueues work.
 */

import { registerJob } from "./queue.js";
import { cacheDelByPattern } from "../utils/cache.js";
import {
  sendNotification,
  type NotificationPayload,
} from "../../services/notification.service.js";
import logger from "../../config/logger.js";

/**
 * Delivers a notification through the notification-service. Fail-open:
 * delivery problems are logged by the client and never surface to requests.
 */
registerJob<NotificationPayload>("notification.send", async (payload) => {
  await sendNotification(payload);
});

/**
 * Invalidates cached analytics for a user. Enqueued by task mutations so
 * task writes do not pay for cache maintenance inside the request path.
 */
registerJob<{ userId: string }>("analytics.invalidate", async ({ userId }) => {
  const deleted = await cacheDelByPattern(`analytics:v1:weekly:${userId}:*`);
  logger.info("job.analytics_invalidate.done", { userId, deleted });
});

export { enqueue, getJobStats } from "./queue.js";
