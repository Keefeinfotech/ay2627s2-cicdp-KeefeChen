import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const create = vi.fn();
  const find = vi.fn();
  const findOne = vi.fn();
  const countDocuments = vi.fn();
  const findOneAndUpdate = vi.fn();
  const updateMany = vi.fn();
  const findOneAndDelete = vi.fn();
  const deleteMany = vi.fn();

  return {
    create,
    find,
    findOne,
    countDocuments,
    findOneAndUpdate,
    updateMany,
    findOneAndDelete,
    deleteMany,
    Notification: {
      create,
      find,
      findOne,
      countDocuments,
      findOneAndUpdate,
      updateMany,
      findOneAndDelete,
      deleteMany,
    },
    NotificationDevice: {
      find,
      findOneAndUpdate,
      findOneAndDelete,
    },
  };
});

vi.mock("../../../../src/modules/notifications/notification.model.js", () => ({
  Notification: mocks.Notification,
  NotificationDevice: mocks.NotificationDevice,
}));

import { notificationService } from "../../../../src/modules/notifications/notification.service.js";

const leanQuery = (value: unknown) => ({
  sort: vi.fn().mockReturnThis(),
  skip: vi.fn().mockReturnThis(),
  limit: vi.fn().mockReturnThis(),
  lean: vi.fn().mockResolvedValue(value),
});

describe("notificationService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.create.mockResolvedValue({
      toObject: () => ({ _id: "n-1", read: false }),
    });
    mocks.find.mockReturnValue(leanQuery([{ _id: "n-1", read: false }]));
    mocks.countDocuments.mockResolvedValue(1);
    mocks.findOne.mockReturnValue(leanQuery({ _id: "n-1" }));
    mocks.findOneAndUpdate.mockReturnValue(leanQuery({ _id: "n-1" }));
    mocks.findOneAndDelete.mockResolvedValue({ _id: "n-1" });
    mocks.updateMany.mockResolvedValue({ modifiedCount: 1 });
    mocks.deleteMany.mockResolvedValue({ deletedCount: 1 });
  });

  it("creates an in-app notification", async () => {
    const result = await notificationService.create("user-1", {
      type: "system",
      title: "Hello",
      body: "World",
    });
    expect(mocks.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "user-1", title: "Hello" }),
    );
    expect(result).toMatchObject({ _id: "n-1" });
  });

  it("lists notifications with pagination", async () => {
    const result = await notificationService.list("user-1", {
      page: 2,
      limit: 10,
      read: false,
    });
    expect(result.items).toHaveLength(1);
    expect(result.pagination).toMatchObject({
      page: 2,
      limit: 10,
      total: 1,
      totalPages: 1,
      hasPreviousPage: true,
    });
  });

  it("uses pagination and read defaults when options are absent", async () => {
    const result = await notificationService.list("user-1", {});
    expect(result.pagination).toMatchObject({
      page: 1,
      limit: 20,
      hasPreviousPage: false,
    });
  });

  it("reads, marks and removes a notification", async () => {
    await expect(
      notificationService.getById("user-1", "n-1"),
    ).resolves.toBeTruthy();
    await expect(
      notificationService.markRead("user-1", "n-1"),
    ).resolves.toBeTruthy();
    await expect(
      notificationService.remove("user-1", "n-1"),
    ).resolves.toBeTruthy();
    expect(mocks.findOneAndUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ _id: "n-1" }),
      { $set: { read: true, readAt: expect.any(Date) } },
      { new: true },
    );
  });

  it("clamps page and limit, and filters by read state", async () => {
    const result = await notificationService.list("user-1", {
      page: -5,
      limit: 999,
      read: true,
    });
    expect(result.pagination).toMatchObject({
      page: 1,
      limit: 100,
      hasPreviousPage: false,
    });
  });

  it("counts unread, marks all read and clears all", async () => {
    await expect(notificationService.unreadCount("user-1")).resolves.toBe(1);
    await expect(notificationService.markAllRead("user-1")).resolves.toBe(1);
    await expect(notificationService.clearAll("user-1")).resolves.toBe(1);
  });

  it("registers, unregisters and lists devices", async () => {
    await expect(
      notificationService.registerDevice("user-1", {
        token: "device-token",
        platform: "android",
      }),
    ).resolves.toBeTruthy();
    expect(mocks.findOneAndUpdate).toHaveBeenCalledWith(
      {
        userId: { $eq: "user-1" },
        token: { $eq: "device-token" },
      },
      { $set: { platform: "android" } },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );
    await expect(
      notificationService.unregisterDevice("user-1", "device-1"),
    ).resolves.toBeTruthy();
    mocks.find.mockReturnValue(leanQuery([{ _id: "device-1" }]));
    await expect(notificationService.listDevices("user-1")).resolves.toEqual([
      { _id: "device-1" },
    ]);
  });
});
