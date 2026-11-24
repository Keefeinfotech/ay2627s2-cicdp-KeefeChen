import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  submitFeedback: vi.fn(),
  getUserFeedbacks: vi.fn(),
  getAllFeedback: vi.fn(),
  getById: vi.fn(),
  updateStatus: vi.fn(),
  addResponse: vi.fn(),
  updateFeedback: vi.fn(),
  deleteFeedback: vi.fn(),
  getAnalytics: vi.fn(),
}));

vi.mock("../../../../src/modules/feedback/feedback.service.js", () => ({
  FeedbackService: vi.fn().mockImplementation(function (this: unknown) {
    return {
      submitFeedback: mocks.submitFeedback,
      getUserFeedbacks: mocks.getUserFeedbacks,
      getAllFeedback: mocks.getAllFeedback,
      getById: mocks.getById,
      updateStatus: mocks.updateStatus,
      addResponse: mocks.addResponse,
      updateFeedback: mocks.updateFeedback,
      deleteFeedback: mocks.deleteFeedback,
      getAnalytics: mocks.getAnalytics,
    };
  }),
}));

import * as feedbackController from "../../../../src/modules/feedback/feedback.controller.js";

const call =
  (
    handler: (
      req: unknown,
      res: unknown,
      next: ReturnType<typeof vi.fn>,
    ) => Promise<void>,
  ) =>
  async (req: unknown) => {
    const res: any = {
      status: vi.fn().mockReturnThis(),
      json: vi.fn().mockReturnThis(),
    };
    const next = vi.fn();
    await handler(req as never, res, next);
    return { res, next };
  };

describe("feedback controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("submits feedback and returns 201", async () => {
    mocks.submitFeedback.mockResolvedValue({ id: "fb-1" });
    const { res } = await call(feedbackController.createFeedback)({
      userId: "user-1",
      body: { title: "T", description: "D" },
    });

    expect(mocks.submitFeedback).toHaveBeenCalledWith("user-1", {
      title: "T",
      description: "D",
    });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { id: "fb-1" },
    });
  });

  it("rejects feedback submission without a user", async () => {
    const { res } = await call(feedbackController.createFeedback)({ body: {} });

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      message: "Unauthorized request",
    });
  });

  it("returns the caller's feedback history", async () => {
    mocks.getUserFeedbacks.mockResolvedValue([{ id: "fb-1" }]);
    const { res } = await call(feedbackController.getMyFeedback)({
      userId: "user-1",
    });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: [{ id: "fb-1" }],
    });
  });

  it("returns global feedback analytics", async () => {
    mocks.getAnalytics.mockResolvedValue({ totalCount: 3 });
    const { res } = await call(feedbackController.getFeedbackAnalytics)({});

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      data: { totalCount: 3 },
    });
  });

  it("returns all feedback for admins", async () => {
    mocks.getAllFeedback.mockResolvedValue([]);
    const { res } = await call(feedbackController.getAllFeedback)({});

    expect(res.status).toHaveBeenCalledWith(200);
    expect(mocks.getAllFeedback).toHaveBeenCalled();
  });

  it("extracts a numeric feedback id from a params object", async () => {
    mocks.updateStatus.mockResolvedValue({ id: "42", status: "PENDING" });
    const { res } = await call(feedbackController.updateFeedbackStatus)({
      params: { id: "42" },
      body: { status: "PENDING" },
    });

    expect(mocks.updateStatus).toHaveBeenCalledWith("42", "PENDING");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("maps missing feedback to a 404", async () => {
    mocks.updateStatus.mockRejectedValue(new Error("Feedback item not found"));

    const { res, next } = await call(feedbackController.updateFeedbackStatus)({
      params: { id: "42" },
      body: { status: "PENDING" },
    });

    expect(res.status).toHaveBeenCalledWith(404);
    expect(next).not.toHaveBeenCalled();
  });

  it("maps unexpected update errors to the error handler", async () => {
    mocks.updateStatus.mockRejectedValue(new Error("boom"));
    const { res: _res, next } = await call(
      feedbackController.updateFeedbackStatus,
    )({
      params: { id: "42" },
      body: { status: "PENDING" },
    });

    expect(next).toHaveBeenCalled();
  });

  it("adds an admin response", async () => {
    mocks.addResponse.mockResolvedValue({ id: "fb-1" });
    const { res } = await call(feedbackController.respondToFeedback)({
      params: { id: "fb-1" },
      userId: "admin-1",
      body: { response: "Fixed" },
    });

    expect(mocks.addResponse).toHaveBeenCalledWith("fb-1", "admin-1", "Fixed");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns feedback by id, allowing admins through", async () => {
    mocks.getById.mockResolvedValue({ id: "fb-1" });
    const { res } = await call(feedbackController.getFeedbackById)({
      params: { id: "fb-1" },
      userId: "user-1",
      userRole: "ADMIN",
    });

    expect(mocks.getById).toHaveBeenCalledWith("fb-1", "user-1", true);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns feedback by id for the owner", async () => {
    mocks.getById.mockResolvedValue({ id: "fb-1", userId: "user-1" });
    const { res } = await call(feedbackController.getFeedbackById)({
      params: { id: "fb-1" },
      userId: "user-1",
    });

    expect(mocks.getById).toHaveBeenCalledWith("fb-1", "user-1", false);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("maps unauthorized feedback reads to 403", async () => {
    mocks.getById.mockRejectedValue(
      new Error("Unauthorized access to feedback"),
    );
    const { res } = await call(feedbackController.getFeedbackById)({
      params: { id: "fb-1" },
      userId: "user-1",
    });

    expect(res.status).toHaveBeenCalledWith(403);
  });

  it("maps not-found feedback reads to 404", async () => {
    mocks.getById.mockRejectedValue(new Error("Feedback item not found"));
    const { res } = await call(feedbackController.getFeedbackById)({
      params: { id: "fb-1" },
      userId: "user-1",
      userRole: "ADMIN",
    });

    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("updates feedback as an admin", async () => {
    mocks.updateFeedback.mockResolvedValue({ id: "fb-1" });
    const { res } = await call(feedbackController.updateFeedback)({
      params: { id: "fb-1" },
      userId: "admin-1",
      userRole: "ADMIN",
      body: { rating: 5 },
    });

    expect(mocks.updateFeedback).toHaveBeenCalledWith("fb-1", "admin-1", true, {
      rating: 5,
    });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 404 when deleting feedback fails", async () => {
    mocks.deleteFeedback.mockResolvedValue(false);
    const { res } = await call(feedbackController.deleteFeedback)({
      params: { id: "fb-1" },
      userId: "user-1",
    });

    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("deletes feedback successfully", async () => {
    mocks.deleteFeedback.mockResolvedValue(true);
    const { res } = await call(feedbackController.deleteFeedback)({
      params: { id: "fb-1" },
      userId: "user-1",
      userRole: "ADMIN",
    });

    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      success: true,
      message: "Feedback deleted successfully",
    });
  });
});
