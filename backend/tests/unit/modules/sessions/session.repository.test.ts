import { beforeEach, describe, expect, it, vi } from "vitest";

const { modelMock } = vi.hoisted(() => {
  const model: any = {
    create: vi.fn(),
    findOne: vi.fn(),
    find: vi.fn(),
    countDocuments: vi.fn(),
    findOneAndUpdate: vi.fn(),
    deleteOne: vi.fn(),
  };
  return { modelMock: model };
});

vi.mock("../../../../src/modules/sessions/session.model.js", () => ({
  StudySession: modelMock,
}));

import { sessionRepository } from "../../../../src/modules/sessions/session.repository.js";

const chainFind = (value: unknown) => {
  const q: any = { exec: vi.fn().mockResolvedValue(value) };
  q.sort = vi.fn().mockReturnValue(q);
  q.skip = vi.fn().mockReturnValue(q);
  q.limit = vi.fn().mockReturnValue(q);
  q.lean = vi.fn().mockReturnValue(q);
  return q;
};
const chainLean = (value: unknown) => ({
  lean: vi.fn().mockReturnValue({ exec: vi.fn().mockResolvedValue(value) }),
  exec: vi.fn().mockResolvedValue(value),
  ...{ lean: vi.fn().mockResolvedValue(value) },
});

describe("sessionRepository", () => {
  beforeEach(() => vi.clearAllMocks());

  it("creates a session", async () => {
    modelMock.create.mockResolvedValue({ toObject: () => ({ _id: "s1" }) });
    await expect(
      sessionRepository.create({ groupId: "g1" } as never),
    ).resolves.toEqual({ _id: "s1" });
  });

  it("finds by id", async () => {
    modelMock.findOne.mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "s1" }),
    });
    await expect(sessionRepository.findById("s1")).resolves.toEqual({
      _id: "s1",
    });
  });

  it("lists by group with filters and pagination", async () => {
    modelMock.find.mockReturnValue(chainFind([{ _id: "s1" }]));
    modelMock.countDocuments.mockReturnValue({
      exec: vi.fn().mockResolvedValue(1),
    });

    const res = await sessionRepository.listByGroup("g1", {
      status: "scheduled" as never,
      from: new Date("2026-01-01"),
      to: new Date("2026-02-01"),
      page: 1,
      limit: 10,
    });
    expect(res.items).toHaveLength(1);
    expect(res.pagination.totalItems).toBe(1);
    expect(modelMock.find).toHaveBeenCalledWith(
      expect.objectContaining({ groupId: "g1", status: "scheduled" }),
    );
  });

  it("updates a session", async () => {
    modelMock.findOneAndUpdate.mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "s1", title: "N" }),
    });
    await expect(
      sessionRepository.update("s1", "g1", { title: "N" }),
    ).resolves.toEqual({ _id: "s1", title: "N" });
  });

  it("joins a session with capacity", async () => {
    modelMock.findOneAndUpdate.mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "s1" }),
    });
    await expect(sessionRepository.join("s1", "g1", "u1", 10)).resolves.toEqual(
      { _id: "s1" },
    );
    expect(modelMock.findOneAndUpdate).toHaveBeenCalledWith(
      expect.objectContaining({ _id: "s1", groupId: "g1" }),
      { $addToSet: { attendeeIds: "u1" } },
      { new: true },
    );
  });

  it("joins a session without capacity limit", async () => {
    modelMock.findOneAndUpdate.mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "s1" }),
    });
    await sessionRepository.join("s1", "g1", "u1", null);
    expect(modelMock.findOneAndUpdate).toHaveBeenCalled();
  });

  it("leaves a session", async () => {
    modelMock.findOneAndUpdate.mockReturnValue({
      lean: vi.fn().mockResolvedValue({ _id: "s1" }),
    });
    await expect(sessionRepository.leave("s1", "g1", "u1")).resolves.toEqual({
      _id: "s1",
    });
  });

  it("removes a session", async () => {
    modelMock.deleteOne.mockReturnValue({
      exec: vi.fn().mockResolvedValue({ deletedCount: 1 }),
    });
    await expect(sessionRepository.remove("s1", "g1")).resolves.toBe(true);
  });

  it("returns false when remove misses", async () => {
    modelMock.deleteOne.mockReturnValue({
      exec: vi.fn().mockResolvedValue({ deletedCount: 0 }),
    });
    await expect(sessionRepository.remove("s1", "g1")).resolves.toBe(false);
  });
});
