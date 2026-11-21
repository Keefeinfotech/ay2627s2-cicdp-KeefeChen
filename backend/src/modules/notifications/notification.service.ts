/**
 * File Name: notification.service.ts
 * Description: In-app notification persistence and device registry.
 * Author: Keefe Chen
 */

import { literal, requireString } from "../../shared/utils/queryGuard.js";

import {
  Notification,
  NotificationDevice,
  type NotificationRecord,
  type NotificationType,
} from "./notification.model.js";

export interface CreateNotificationInput {
  type: NotificationType;
  title: string;
  body: string;
  entityId?: string | null;
}

export interface ListNotificationsOptions {
  page?: number;
  limit?: number;
  read?: boolean;
}

export const notificationService = {
  async create(
    userId: string,
    input: CreateNotificationInput,
  ): Promise<NotificationRecord> {
    const doc = await Notification.create({
      userId,
      type: input.type,
      title: input.title,
      body: input.body,
      entityId: input.entityId ?? null,
    });
    return doc.toObject() as NotificationRecord;
  },

  async list(userId: string, options: ListNotificationsOptions) {
    const page = Math.max(options.page ?? 1, 1);
    const limit = Math.min(Math.max(options.limit ?? 20, 1), 100);

    const filter: Record<string, unknown> = { userId };
    if (typeof options.read === "boolean") filter.read = options.read;

    const [items, total] = await Promise.all([
      Notification.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .lean(),
      Notification.countDocuments(filter),
    ]);

    return {
      items,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.max(1, Math.ceil(total / limit)),
        hasNextPage: page * limit < total,
        hasPreviousPage: page > 1,
      },
    };
  },

  async getById(userId: string, id: string) {
    return Notification.findOne({ _id: id, userId }).lean();
  },

  async unreadCount(userId: string): Promise<number> {
    return Notification.countDocuments({ userId, read: false });
  },

  async markRead(userId: string, id: string) {
    return Notification.findOneAndUpdate(
      { _id: id, userId },
      { $set: { read: true, readAt: new Date() } },
      { new: true },
    ).lean();
  },

  async markAllRead(userId: string): Promise<number> {
    const result = await Notification.updateMany(
      { userId, read: false },
      { $set: { read: true, readAt: new Date() } },
    );
    return result.modifiedCount;
  },

  async remove(userId: string, id: string) {
    return Notification.findOneAndDelete({ _id: id, userId });
  },

  async clearAll(userId: string): Promise<number> {
    const result = await Notification.deleteMany({ userId });
    return result.deletedCount ?? 0;
  },

  /** Registers (or refreshes) a device push token. Idempotent per user+token. */
  async registerDevice(
    userId: string,
    input: { token: string; platform: "ios" | "android" | "web" },
  ) {
    const token = requireString(input.token, "device token");
    return NotificationDevice.findOneAndUpdate(
      { userId: literal(userId), token: literal(token) },
      { $set: { platform: input.platform } },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    ).lean();
  },

  async unregisterDevice(userId: string, deviceId: string) {
    return NotificationDevice.findOneAndDelete({ _id: deviceId, userId });
  },

  async listDevices(userId: string) {
    return NotificationDevice.find({ userId }).sort({ createdAt: -1 }).lean();
  },
};
