/**
 * File Name: notification.validation.ts
 * Description: Zod schemas for notification endpoints.
 */

import { z } from "zod";

import { DEVICE_PLATFORMS, NOTIFICATION_TYPES } from "./notification.model.js";

export const notificationIdParamSchema = z.object({
  params: z.object({ notificationId: z.string().min(1) }),
});

export const listNotificationsSchema = z.object({
  query: z
    .object({
      page: z.coerce.number().int().min(1).default(1),
      limit: z.coerce.number().int().min(1).max(100).default(20),
      read: z
        .enum(["true", "false"])
        .optional()
        .transform((v) => (v === undefined ? undefined : v === "true")),
    })
    .strict(),
});

export const registerDeviceSchema = z.object({
  body: z
    .object({
      token: z.string().trim().min(1).max(512),
      platform: z.enum(DEVICE_PLATFORMS),
    })
    .strict(),
});

export const deviceIdParamSchema = z.object({
  params: z.object({ deviceId: z.string().min(1) }),
});

export const createNotificationSchema = z.object({
  body: z
    .object({
      type: z.enum(NOTIFICATION_TYPES).default("system"),
      title: z.string().trim().min(1).max(200),
      body: z.string().trim().min(1).max(1000),
      entityId: z.string().max(64).nullish(),
    })
    .strict(),
});
