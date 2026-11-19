/**
 * File Name: notification.service.ts
 * Description: Thin HTTP client for the notification-service prototype
 *              (backend/prototype/notification-service). Fails open: when
 *              NOTIFICATION_SERVICE_URL is unset or the service is
 *              unreachable, the notification is logged and dropped instead of
 *              breaking the calling workflow.
 */

import logger from "../config/logger.js";

export interface NotificationPayload {
  to: string;
  channel?: "email" | "push" | "in_app";
  subject?: string;
  message: string;
}

const getBaseUrl = (): string | null => {
  const url = process.env.NOTIFICATION_SERVICE_URL?.trim();
  return url ? url.replace(/\/+$/, "") : null;
};

export const sendNotification = async (
  payload: NotificationPayload,
): Promise<boolean> => {
  const baseUrl = getBaseUrl();

  if (!baseUrl) {
    logger.info("notification.skipped_not_configured", {
      channel: payload.channel ?? "email",
    });
    return false;
  }

  try {
    const response = await fetch(`${baseUrl}/notify`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ channel: "email", ...payload }),
      signal: AbortSignal.timeout(2_000),
    });

    if (!response.ok) {
      logger.warn("notification.delivery_failed", {
        status: response.status,
      });
      return false;
    }

    return true;
  } catch (error) {
    logger.warn("notification.service_unreachable", {
      error: error instanceof Error ? error.message : String(error),
    });
    return false;
  }
};
