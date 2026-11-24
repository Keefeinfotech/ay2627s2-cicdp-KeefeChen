import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  list: vi.fn(),
  unreadCount: vi.fn(),
  getById: vi.fn(),
  markRead: vi.fn(),
  markAllRead: vi.fn(),
  remove: vi.fn(),
  clearAll: vi.fn(),
  registerDevice: vi.fn(),
  listDevices: vi.fn(),
  unregisterDevice: vi.fn(),
}));

vi.mock(
  "../../../../src/modules/notifications/notification.service.js",
  () => ({
    notificationService: mocks,
  }),
);

import { notificationController } from "../../../../src/modules/notifications/notification.controller.js";

const createRes = () => {
  const res: any = {};
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  res.send = vi.fn().mockReturnValue(res);
  return res as Response;
};

describe("notificationController", () => {
  let next: NextFunction;

  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("list returns 401 when unauthenticated", async () => {
    const res = createRes();
    await notificationController.list({ query: {} } as any, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(mocks.list).not.toHaveBeenCalled();
  });

  it("list returns notifications for user", async () => {
    mocks.list.mockResolvedValue({
      items: [{ id: "1" }],
      pagination: { page: 1 },
    });
    const res = createRes();
    await notificationController.list(
      { userId: "u1", query: { page: 1, limit: 10, read: true } } as any,
      res,
      next,
    );
    expect(mocks.list).toHaveBeenCalledWith("u1", {
      page: 1,
      limit: 10,
      read: true,
    });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("list forwards errors", async () => {
    mocks.list.mockRejectedValue(new Error("boom"));
    await notificationController.list(
      { userId: "u1", query: {} } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });

  it("unreadCount returns count and handles unauthenticated", async () => {
    const res401 = createRes();
    await notificationController.unreadCount({} as any, res401, next);
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.unreadCount.mockResolvedValue(3);
    const res = createRes();
    await notificationController.unreadCount(
      { userId: "u1" } as any,
      res,
      next,
    );
    expect(res.json).toHaveBeenCalledWith({
      message: "Unread count retrieved successfully.",
      data: { unread: 3 },
    });
  });

  it("show returns 404 when missing and 200 when found", async () => {
    mocks.getById.mockResolvedValueOnce(null);
    await notificationController.show(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ status: 404 }));

    next = vi.fn() as any;
    mocks.getById.mockResolvedValueOnce({ _id: "n1" });
    const res = createRes();
    await notificationController.show(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("show returns 401 when unauthenticated", async () => {
    const res = createRes();
    await notificationController.show(
      { params: { notificationId: "n1" } } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("markRead handles 401, 404, and success", async () => {
    const res401 = createRes();
    await notificationController.markRead(
      { params: { notificationId: "n1" } } as any,
      res401,
      next,
    );
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.markRead.mockResolvedValueOnce(null);
    await notificationController.markRead(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ status: 404 }));

    next = vi.fn() as any;
    mocks.markRead.mockResolvedValueOnce({ _id: "n1", read: true });
    const res = createRes();
    await notificationController.markRead(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("markAllRead handles 401 and success", async () => {
    const res401 = createRes();
    await notificationController.markAllRead({} as any, res401, next);
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.markAllRead.mockResolvedValue(5);
    const res = createRes();
    await notificationController.markAllRead(
      { userId: "u1" } as any,
      res,
      next,
    );
    expect(res.json).toHaveBeenCalledWith({
      message: "All notifications marked as read.",
      data: { updated: 5 },
    });
  });

  it("remove handles 401, 404, and success", async () => {
    const res401 = createRes();
    await notificationController.remove(
      { params: { notificationId: "n1" } } as any,
      res401,
      next,
    );
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.remove.mockResolvedValueOnce(null);
    await notificationController.remove(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ status: 404 }));

    next = vi.fn() as any;
    mocks.remove.mockResolvedValueOnce({ _id: "n1" });
    const res = createRes();
    await notificationController.remove(
      { userId: "u1", params: { notificationId: "n1" } } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(204);
  });

  it("clearAll handles 401 and success", async () => {
    const res401 = createRes();
    await notificationController.clearAll({} as any, res401, next);
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.clearAll.mockResolvedValue(2);
    const res = createRes();
    await notificationController.clearAll({ userId: "u1" } as any, res, next);
    expect(res.json).toHaveBeenCalledWith({
      message: "Notifications cleared.",
      data: { deleted: 2 },
    });
  });

  it("registerDevice handles 401 and success", async () => {
    const res401 = createRes();
    await notificationController.registerDevice(
      { body: {} } as any,
      res401,
      next,
    );
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.registerDevice.mockResolvedValue({ _id: "d1" });
    const res = createRes();
    await notificationController.registerDevice(
      { userId: "u1", body: { token: "t", platform: "web" } } as any,
      res,
      next,
    );
    expect(mocks.registerDevice).toHaveBeenCalledWith("u1", {
      token: "t",
      platform: "web",
    });
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it("listDevices handles 401 and success", async () => {
    const res401 = createRes();
    await notificationController.listDevices({} as any, res401, next);
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.listDevices.mockResolvedValue([{ _id: "d1" }]);
    const res = createRes();
    await notificationController.listDevices(
      { userId: "u1" } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("unregisterDevice handles 401, 404, and success", async () => {
    const res401 = createRes();
    await notificationController.unregisterDevice(
      { params: { deviceId: "d1" } } as any,
      res401,
      next,
    );
    expect(res401.status).toHaveBeenCalledWith(401);

    mocks.unregisterDevice.mockResolvedValueOnce(null);
    await notificationController.unregisterDevice(
      { userId: "u1", params: { deviceId: "d1" } } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ status: 404 }));

    next = vi.fn() as any;
    mocks.unregisterDevice.mockResolvedValueOnce({ _id: "d1" });
    const res = createRes();
    await notificationController.unregisterDevice(
      { userId: "u1", params: { deviceId: "d1" } } as any,
      res,
      next,
    );
    expect(res.status).toHaveBeenCalledWith(204);
  });

  it("forwards errors from handlers", async () => {
    mocks.unreadCount.mockRejectedValue(new Error("x"));
    await notificationController.unreadCount(
      { userId: "u1" } as any,
      createRes(),
      next,
    );
    expect(next).toHaveBeenCalledWith(expect.any(Error));
  });
});
