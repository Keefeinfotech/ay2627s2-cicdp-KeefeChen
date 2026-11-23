/**
 * File Name: notification.model.ts
 * Description: In-app notification and device registration models.
 * Author: Keefe Chen
 */

import { randomUUID } from "node:crypto";
import mongoose, { Schema, type Model } from "mongoose";

export const NOTIFICATION_TYPES = [
  "task",
  "reminder",
  "assignment",
  "system",
  "assistant",
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const DEVICE_PLATFORMS = ["ios", "android", "web"] as const;
export type DevicePlatform = (typeof DEVICE_PLATFORMS)[number];

export interface NotificationRecord {
  _id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  read: boolean;
  readAt: Date | null;
  /** Optional reference to the related entity (task/reminder id). */
  entityId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface DeviceRecord {
  _id: string;
  userId: string;
  token: string;
  platform: DevicePlatform;
  createdAt: Date;
  updatedAt: Date;
}

const notificationSchema = new Schema<NotificationRecord>(
  {
    _id: {
      type: String,
      default: () => randomUUID(),
      immutable: true,
    },
    userId: { type: String, required: true, index: true },
    type: { type: String, enum: NOTIFICATION_TYPES, default: "system" },
    title: { type: String, required: true, trim: true, maxlength: 200 },
    body: { type: String, required: true, trim: true, maxlength: 1000 },
    read: { type: Boolean, default: false, index: true },
    readAt: { type: Date, default: null },
    entityId: { type: String, default: null },
  },
  {
    timestamps: true,
    versionKey: false,
    toJSON: {
      transform: (_doc, result: Record<string, unknown>) => result,
    },
  },
);

notificationSchema.index({ userId: 1, read: 1, createdAt: -1 });

const deviceSchema = new Schema<DeviceRecord>(
  {
    _id: {
      type: String,
      default: () => randomUUID(),
      immutable: true,
    },
    userId: { type: String, required: true, index: true },
    token: { type: String, required: true, maxlength: 512 },
    platform: { type: String, enum: DEVICE_PLATFORMS, required: true },
  },
  { timestamps: true, versionKey: false },
);

deviceSchema.index({ userId: 1, token: 1 }, { unique: true });

export const Notification: Model<NotificationRecord> =
  (mongoose.models.Notification as Model<NotificationRecord>) ??
  mongoose.model<NotificationRecord>("Notification", notificationSchema);

export const NotificationDevice: Model<DeviceRecord> =
  (mongoose.models.NotificationDevice as Model<DeviceRecord>) ??
  mongoose.model<DeviceRecord>("NotificationDevice", deviceSchema);
