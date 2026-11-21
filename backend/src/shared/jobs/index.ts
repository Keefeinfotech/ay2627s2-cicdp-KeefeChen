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
import { notificationService } from "../../modules/notifications/notification.service.js";
import logger from "../../config/logger.js";

interface NotificationJobPayload extends NotificationPayload {
  userId?: string;
  type?: "task" | "reminder" | "assignment" | "system" | "assistant";
  entityId?: string | null;
}

/**
 * Delivers a notification: persists an in-app record when a userId is
 * present, and hands off to the notification-service for external delivery.
 * Fail-open throughout; delivery problems never surface to requests.
 */
registerJob<NotificationJobPayload>("notification.send", async (payload) => {
  if (payload.userId) {
    try {
      await notificationService.create(payload.userId, {
        type: payload.type ?? "system",
        title: payload.subject ?? "Notification",
        body: payload.message,
        entityId: payload.entityId ?? null,
      });
    } catch (error) {
      logger.warn("notification.in_app_persist_failed", {
        userId: payload.userId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

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
