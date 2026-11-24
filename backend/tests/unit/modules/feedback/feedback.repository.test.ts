import { beforeEach, describe, expect, it, vi } from "vitest";

const { modelMock, saveMock } = vi.hoisted(() => {
  const save = vi.fn();
  const model: any = vi.fn().mockImplementation(function (this: any, data: any) {
    Object.assign(this, data);
    this.save = save;
  });
  model.findById = vi.fn();
  model.find = vi.fn();
  model.findByIdAndUpdate = vi.fn();
  model.deleteOne = vi.fn();
  model.countDocuments = vi.fn();
  model.aggregate = vi.fn();
  return { modelMock: model, saveMock: save };
});

vi.mock("../../../../src/modules/feedback/feedback.model.js", () => ({
  FeedbackModel: modelMock,
  FeedbackStatus: { PENDING: "PENDING", IN_REVIEW: "IN_REVIEW", RESOLVED: "RESOLVED", DISMISSED: "DISMISSED" },
}));

import { FeedbackRepository } from "../../../../src/modules/feedback/feedback.repository.js";

const chain = (value: unknown) => {
  const q: any = { exec: vi.fn().mockResolvedValue(value) };
  q.sort = vi.fn().mockReturnValue(q);
  q.populate = vi.fn().mockReturnValue(q);
  return q;
};

describe("FeedbackRepository", () => {
  let repo: FeedbackRepository;

  beforeEach(() => {
    vi.clearAllMocks();
    repo = new FeedbackRepository();
  });

  it("creates feedback", async () => {
    saveMock.mockResolvedValue({ _id: "f1" });
    await expect(repo.create("u1", { title: "T", description: "D" } as never)).resolves.toEqual({ _id: "f1" });
  });

  it("finds by id with populated refs", async () => {
    modelMock.findById.mockReturnValue(chain({ _id: "f1" }));
    await expect(repo.findById("f1")).resolves.toEqual({ _id: "f1" });
  });

  it("finds by user id", async () => {
    modelMock.find.mockReturnValue(chain([{ _id: "f1" }]));
    await expect(repo.findByUserId("u1")).resolves.toEqual([{ _id: "f1" }]);
    expect(modelMock.find).toHaveBeenCalledWith({ userId: "u1" });
  });

  it("finds all feedback", async () => {
    modelMock.find.mockReturnValue(chain([{ _id: "f1" }]));
    await expect(repo.findAll()).resolves.toEqual([{ _id: "f1" }]);
  });

  it("updates feedback", async () => {
    modelMock.findByIdAndUpdate.mockReturnValue(chain({ _id: "f1", rating: 5 }));
    await expect(repo.update("f1", { rating: 5 } as never)).resolves.toEqual({ _id: "f1", rating: 5 });
  });

  it("adds admin response and moves to in_review", async () => {
    modelMock.findByIdAndUpdate.mockReturnValue(chain({ _id: "f1", status: "IN_REVIEW" }));
    const res = await repo.addAdminResponse("f1", "admin-1", "Noted");
    expect(modelMock.findByIdAndUpdate).toHaveBeenCalledWith("f1", expect.objectContaining({ $set: expect.objectContaining({ status: "IN_REVIEW" }) }), { new: true });
    expect(res).toEqual({ _id: "f1", status: "IN_REVIEW" });
  });

  it("deletes by owner scope", async () => {
    modelMock.deleteOne.mockReturnValue(chain({ deletedCount: 1 }));
    await expect(repo.delete("507f1f77bcf86cd799439011", "u1")).resolves.toBe(true);
  });

  it("deletes without user scope", async () => {
    modelMock.deleteOne.mockReturnValue(chain({ deletedCount: 0 }));
    await expect(repo.delete("507f1f77bcf86cd799439011")).resolves.toBe(false);
  });

  it("computes analytics", async () => {
    modelMock.countDocuments.mockResolvedValue(3);
    modelMock.aggregate
      .mockResolvedValueOnce([{ _id: "PENDING", count: 2 }, { _id: "RESOLVED", count: 1 }])
      .mockResolvedValueOnce([{ avgRating: 4.24 }]);

    const res = await repo.getAnalytics();
    expect(res.totalCount).toBe(3);
    expect(res.statusBreakdown.PENDING).toBe(2);
    expect(res.statusBreakdown.RESOLVED).toBe(1);
    expect(res.averageRating).toBe(4.2);
  });
});
