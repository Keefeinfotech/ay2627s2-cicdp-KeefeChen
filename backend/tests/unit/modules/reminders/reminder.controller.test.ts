import type { NextFunction, Request, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  findAll: vi.fn(),
  create: vi.fn(),
  complete: vi.fn(),
  delete: vi.fn(),
  findPending: vi.fn(),
}));

vi.mock("../../../../src/modules/reminders/reminder.service.js", () => ({
  reminderService: mocks,
}));

import { reminderController } from "../../../../src/modules/reminders/reminder.controller.js";

const makeResponse = () => {
  const res = {
    status: vi.fn().mockReturnThis(),
    json: vi.fn().mockReturnThis(),
  } as unknown as Response;
  return res;
};

describe("reminder controller", () => {
  let next: NextFunction;

  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("returns reminders for the authenticated user", async () => {
    const reminders = [{ _id: "reminder-1" }];
    mocks.findAll.mockResolvedValue(reminders);
    const req = { userId: "user-1" } as unknown as Request;
    const res = makeResponse();

    await reminderController.index(req, res, next);

    expect(mocks.findAll).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Reminders retrieved successfully.",
      data: reminders,
    });
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects reminder creation without required fields", async () => {
    const req = { userId: "user-1", body: { message: "Revise" } } as unknown as Request;
    const res = makeResponse();

    await reminderController.create(req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      code: "MISSING_FIELDS",
      message: "Message and dueAt are required.",
    });
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("returns not found when completing a missing reminder", async () => {
    mocks.complete.mockResolvedValue(null);
    const req = {
      userId: "user-1",
      params: { id: "missing" },
    } as unknown as Request;
    const res = makeResponse();

    await reminderController.complete(req, res, next);

    expect(mocks.complete).toHaveBeenCalledWith("missing");
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({
      code: "REMINDER_NOT_FOUND",
      message: "Reminder not found.",
    });
  });

  it("deletes an existing reminder", async () => {
    mocks.delete.mockResolvedValue({ deletedCount: 1 });
    const req = {
      userId: "user-1",
      params: { id: "reminder-1" },
    } as unknown as Request;
    const res = makeResponse();

    await reminderController.remove(req, res, next);

    expect(mocks.delete).toHaveBeenCalledWith("reminder-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Reminder deleted successfully.",
    });
  });

  it("returns pending reminders for the authenticated user", async () => {
    const pending = [{ _id: "reminder-2" }];
    mocks.findPending.mockResolvedValue(pending);
    const req = { userId: "user-1" } as unknown as Request;
    const res = makeResponse();

    await reminderController.pending(req, res, next);

    expect(mocks.findPending).toHaveBeenCalledWith("user-1", expect.any(Date));
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Pending reminders retrieved successfully.",
      data: pending,
    });
  });
});
