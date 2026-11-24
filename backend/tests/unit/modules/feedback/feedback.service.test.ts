import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  findByUserId: vi.fn(),
  findAll: vi.fn(),
  findById: vi.fn(),
  update: vi.fn(),
  addAdminResponse: vi.fn(),
  delete: vi.fn(),
  getAnalytics: vi.fn(),
}));

vi.mock("../../../../src/modules/feedback/feedback.repository.js", () => ({
  FeedbackRepository: vi.fn().mockImplementation(function (this: unknown) {
    return {
      create: mocks.create,
      findByUserId: mocks.findByUserId,
      findAll: mocks.findAll,
      findById: mocks.findById,
      update: mocks.update,
      addAdminResponse: mocks.addAdminResponse,
      delete: mocks.delete,
      getAnalytics: mocks.getAnalytics,
    };
  }),
}));

import { FeedbackService } from "../../../../src/modules/feedback/feedback.service.js";
import { FeedbackStatus } from "../../../../src/modules/feedback/feedback.model.js";

describe("FeedbackService", () => {
  let service: FeedbackService;

  beforeEach(() => {
    vi.clearAllMocks();
    service = new FeedbackService();
  });

  describe("submitFeedback", () => {
    it("creates feedback for the user", async () => {
      const created = { id: "fb-1", userId: "user-1", status: FeedbackStatus.PENDING };
      mocks.create.mockResolvedValue(created);

      const result = await service.submitFeedback("user-1", {
        title: "App crashes",
        description: "Crash on startup",
      });

      expect(mocks.create).toHaveBeenCalledWith("user-1", {
        title: "App crashes",
        description: "Crash on startup",
      });
      expect(result).toEqual(created);
    });
  });

  describe("getUserFeedbacks", () => {
    it("returns the user's feedback history", async () => {
      const list = [{ id: "fb-1" }, { id: "fb-2" }];
      mocks.findByUserId.mockResolvedValue(list);

      await expect(service.getUserFeedbacks("user-1")).resolves.toEqual(list);
      expect(mocks.findByUserId).toHaveBeenCalledWith("user-1");
    });
  });

  describe("getAllFeedback", () => {
    it("returns every feedback item", async () => {
      const all = [{ id: "fb-1" }];
      mocks.findAll.mockResolvedValue(all);

      await expect(service.getAllFeedback()).resolves.toEqual(all);
      expect(mocks.findAll).toHaveBeenCalled();
    });
  });

  describe("getById", () => {
    it("returns feedback for the owner", async () => {
      const fb = { id: "fb-1", userId: "user-1" };
      mocks.findById.mockResolvedValue(fb);

      await expect(service.getById("fb-1", "user-1", false)).resolves.toEqual(fb);
      expect(mocks.findById).toHaveBeenCalledWith("fb-1");
    });

    it("allows admins to read any feedback", async () => {
      const fb = { id: "fb-1", userId: "user-2" };
      mocks.findById.mockResolvedValue(fb);

      await expect(service.getById("fb-1", "user-1", true)).resolves.toEqual(fb);
    });

    it("rejects feedback owned by another user", async () => {
      mocks.findById.mockResolvedValue({ id: "fb-1", userId: "user-2" });

      await expect(service.getById("fb-1", "user-1", false)).rejects.toThrow(
        "Unauthorized access to feedback",
      );
    });

    it("throws when feedback is missing", async () => {
      mocks.findById.mockResolvedValue(null);

      await expect(service.getById("fb-missing", "user-1", true)).rejects.toThrow(
        "Feedback item not found",
      );
    });
  });

  describe("updateStatus", () => {
    it("updates the status of an existing item", async () => {
      const updated = { id: "fb-1", status: FeedbackStatus.RESOLVED };
      mocks.update.mockResolvedValue(updated);

      await expect(service.updateStatus("fb-1", FeedbackStatus.RESOLVED)).resolves.toEqual(
        updated,
      );
      expect(mocks.update).toHaveBeenCalledWith("fb-1", { status: FeedbackStatus.RESOLVED });
    });

    it("throws when the item does not exist", async () => {
      mocks.update.mockResolvedValue(null);

      await expect(service.updateStatus("fb-missing", FeedbackStatus.RESOLVED)).rejects.toThrow(
        "Feedback item not found",
      );
    });
  });

  describe("addResponse", () => {
    it("records an admin response and moves the item to review", async () => {
      const updated = { id: "fb-1", status: FeedbackStatus.IN_REVIEW };
      mocks.addAdminResponse.mockResolvedValue(updated);

      await expect(
        service.addResponse("fb-1", "admin-1", "We are on it"),
      ).resolves.toEqual(updated);

      expect(mocks.addAdminResponse).toHaveBeenCalledWith("fb-1", "admin-1", "We are on it");
    });

    it("throws when the item does not exist", async () => {
      mocks.addAdminResponse.mockResolvedValue(null);

      await expect(service.addResponse("fb-missing", "admin-1", "hello")).rejects.toThrow(
        "Feedback item not found",
      );
    });
  });

  describe("updateFeedback", () => {
    it("lets the owner update their feedback", async () => {
      const existing = { id: "fb-1", userId: "user-1" };
      const updated = { ...existing, rating: 4 };

      mocks.findById.mockResolvedValue(existing);
      mocks.update.mockResolvedValue(updated);

      await expect(
        service.updateFeedback("fb-1", "user-1", false, { rating: 4 }),
      ).resolves.toEqual(updated);
    });

    it("lets an admin update any feedback", async () => {
      mocks.findById.mockResolvedValue({ id: "fb-1", userId: "user-2" });
      mocks.update.mockResolvedValue({ id: "fb-1", rating: 5 });

      await expect(
        service.updateFeedback("fb-1", "admin-1", true, { rating: 5 }),
      ).resolves.toEqual({ id: "fb-1", rating: 5 });
    });

    it("rejects updates from other users", async () => {
      mocks.findById.mockResolvedValue({ id: "fb-1", userId: "user-2" });

      await expect(
        service.updateFeedback("fb-1", "user-1", false, { rating: 5 }),
      ).rejects.toThrow("Unauthorized update request");
    });

    it("throws when the item is missing", async () => {
      mocks.findById.mockResolvedValue(null);

      await expect(
        service.updateFeedback("fb-missing", "user-1", true, { rating: 5 }),
      ).rejects.toThrow("Feedback item not found");
    });
  });

  describe("deleteFeedback", () => {
    it("deletes feedback for the owner", async () => {
      mocks.delete.mockResolvedValue(true);

      await expect(service.deleteFeedback("fb-1", "user-1", false)).resolves.toBe(true);
      expect(mocks.delete).toHaveBeenCalledWith("fb-1", "user-1");
    });

    it("deletes any feedback for admins", async () => {
      mocks.delete.mockResolvedValue(true);

      await expect(service.deleteFeedback("fb-1", "admin-1", true)).resolves.toBe(true);
      expect(mocks.delete).toHaveBeenCalledWith("fb-1", undefined);
    });

    it("returns false when nothing was deleted", async () => {
      mocks.delete.mockResolvedValue(false);

      await expect(service.deleteFeedback("fb-missing", "user-1", false)).resolves.toBe(false);
    });
  });

  describe("getAnalytics", () => {
    it("aggregates feedback metrics", async () => {
      mocks.getAnalytics.mockResolvedValue({
        totalCount: 5,
        statusBreakdown: { PENDING: 2, IN_REVIEW: 1 },
        averageRating: 4,
      });

      await expect(service.getAnalytics()).resolves.toEqual({
        totalCount: 5,
        statusBreakdown: { PENDING: 2, IN_REVIEW: 1 },
        averageRating: 4,
      });
    });
  });
});
