import type { NextFunction, Response } from "express";
import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  submitFeedback: vi.fn(),
  getUserFeedbacks: vi.fn(),
  getAnalytics: vi.fn(),
  getAllFeedback: vi.fn(),
  updateStatus: vi.fn(),
  addResponse: vi.fn(),
  getById: vi.fn(),
  updateFeedback: vi.fn(),
  deleteFeedback: vi.fn(),
}));

vi.mock("../../../../src/modules/feedback/feedback.service.js", () => ({
  FeedbackService: vi.fn().mockImplementation(function () {
    return mocks;
  }),
}));

import {
  createFeedback,
  getMyFeedback,
  getFeedbackAnalytics,
  getAllFeedback,
  updateFeedbackStatus,
  respondToFeedback,
  getFeedbackById,
  updateFeedback,
  deleteFeedback,
} from "../../../../src/modules/feedback/feedback.controller.js";

const res = () => {
  const r: any = {};
  r.status = vi.fn().mockReturnValue(r);
  r.json = vi.fn().mockReturnValue(r);
  return r as Response;
};

describe("feedback controller", () => {
  let next: NextFunction;
  beforeEach(() => {
    vi.clearAllMocks();
    next = vi.fn() as unknown as NextFunction;
  });

  it("createFeedback handles 401, success, error", async () => {
    const r401 = res();
    await createFeedback({ body: {} } as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);

    mocks.submitFeedback.mockResolvedValueOnce({ _id: "f1" });
    const r = res();
    await createFeedback(
      { userId: "u1", body: { message: "hi" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(201);

    mocks.submitFeedback.mockRejectedValueOnce(new Error("boom"));
    await createFeedback({ userId: "u1", body: {} } as any, res(), next);
    expect(next).toHaveBeenCalled();
  });

  it("getMyFeedback handles 401 and success", async () => {
    const r401 = res();
    await getMyFeedback({} as any, r401, next);
    expect(r401.status).toHaveBeenCalledWith(401);
    mocks.getUserFeedbacks.mockResolvedValueOnce([]);
    const r = res();
    await getMyFeedback({ user: { id: "u1" } } as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("getFeedbackAnalytics and getAllFeedback return data", async () => {
    mocks.getAnalytics.mockResolvedValueOnce({ total: 1 });
    let r = res();
    await getFeedbackAnalytics({} as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.getAllFeedback.mockResolvedValueOnce([]);
    r = res();
    await getAllFeedback({} as any, r, next);
    expect(r.status).toHaveBeenCalledWith(200);
  });

  it("updateFeedbackStatus handles success and not found", async () => {
    mocks.updateStatus.mockResolvedValueOnce({ _id: "f1" });
    let r = res();
    await updateFeedbackStatus(
      { params: { id: "f1" }, body: { status: "open" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.updateStatus.mockRejectedValueOnce(new Error("not found"));
    r = res();
    await updateFeedbackStatus(
      { params: { id: "missing" }, body: { status: "open" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);

    mocks.updateStatus.mockRejectedValueOnce(new Error("other"));
    await updateFeedbackStatus(
      { params: { id: "f1" }, body: { status: "open" } } as any,
      res(),
      next,
    );
    expect(next).toHaveBeenCalled();
  });

  it("respondToFeedback handles success and not found", async () => {
    mocks.addResponse.mockResolvedValueOnce({ _id: "f1" });
    let r = res();
    await respondToFeedback(
      { params: { id: "f1" }, userId: "a1", body: { response: "ok" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.addResponse.mockRejectedValueOnce(new Error("not found"));
    r = res();
    await respondToFeedback(
      { params: { id: "x" }, userId: "a1", body: { response: "ok" } } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);
  });

  it("getFeedbackById handles success, unauthorized, not found", async () => {
    mocks.getById.mockResolvedValueOnce({ _id: "f1" });
    let r = res();
    await getFeedbackById(
      { params: { id: "f1" }, userId: "u1", userRole: "USER" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.getById.mockRejectedValueOnce(new Error("Unauthorized access"));
    r = res();
    await getFeedbackById(
      { params: { id: "f1" }, userId: "u1" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(403);

    mocks.getById.mockRejectedValueOnce(new Error("not found"));
    r = res();
    await getFeedbackById(
      { params: { id: "f1" }, userId: "u1" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);
  });

  it("updateFeedback handles success, unauthorized, not found", async () => {
    mocks.updateFeedback.mockResolvedValueOnce({ _id: "f1" });
    let r = res();
    await updateFeedback(
      { params: { id: "f1" }, userId: "u1", userRole: "ADMIN" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.updateFeedback.mockRejectedValueOnce(new Error("Unauthorized"));
    r = res();
    await updateFeedback(
      { params: { id: "f1" }, userId: "u1" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(403);

    mocks.updateFeedback.mockRejectedValueOnce(new Error("not found"));
    r = res();
    await updateFeedback(
      { params: { id: "f1" }, userId: "u1" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);
  });

  it("deleteFeedback handles success and not found/unauthorized", async () => {
    mocks.deleteFeedback.mockResolvedValueOnce(true);
    let r = res();
    await deleteFeedback(
      { params: { id: "f1" }, userId: "u1", userRole: "ADMIN" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(200);

    mocks.deleteFeedback.mockResolvedValueOnce(false);
    r = res();
    await deleteFeedback(
      { params: { id: "f1" }, userId: "u1" } as any,
      r,
      next,
    );
    expect(r.status).toHaveBeenCalledWith(404);
  });
});
