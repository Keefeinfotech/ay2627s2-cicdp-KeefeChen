import { beforeEach, describe, expect, it, vi } from "vitest";

const { modelMock } = vi.hoisted(() => {
  const model: any = {
    create: vi.fn(),
    findOne: vi.fn(),
    find: vi.fn(),
    countDocuments: vi.fn(),
    deleteOne: vi.fn(),
  };
  return { modelMock: model };
});

vi.mock("../../../../src/modules/rubrics/rubric.model.js", () => ({
  Rubric: modelMock,
}));

import { rubricRepository } from "../../../../src/modules/rubrics/rubric.repository.js";

const chainFind = (value: unknown) => {
  const q: any = { exec: vi.fn().mockResolvedValue(value) };
  q.sort = vi.fn().mockReturnValue(q);
  q.skip = vi.fn().mockReturnValue(q);
  q.limit = vi.fn().mockReturnValue(q);
  q.lean = vi.fn().mockReturnValue(q);
  return q;
};

describe("rubricRepository", () => {
  beforeEach(() => vi.clearAllMocks());

  it("creates a rubric", async () => {
    modelMock.create.mockResolvedValue({ toObject: () => ({ _id: "r1" }) });
    await expect(rubricRepository.create({ groupId: "g1" } as never)).resolves.toEqual({ _id: "r1" });
  });

  it("finds by id", async () => {
    modelMock.findOne.mockReturnValue({ lean: vi.fn().mockResolvedValue({ _id: "r1" }) });
    await expect(rubricRepository.findById("r1")).resolves.toEqual({ _id: "r1" });
  });

  it("lists by group with pagination", async () => {
    modelMock.find.mockReturnValue(chainFind([{ _id: "r1" }]));
    modelMock.countDocuments.mockReturnValue({ exec: vi.fn().mockResolvedValue(21) });

    const res = await rubricRepository.listByGroup("g1", 1, 10);
    expect(res.items).toHaveLength(1);
    expect(res.pagination).toEqual({
      page: 1, limit: 10, totalItems: 21, totalPages: 3, hasNextPage: true, hasPreviousPage: false,
    });
  });

  it("finds duplicate by checksum", async () => {
    modelMock.findOne.mockReturnValue({ lean: vi.fn().mockReturnValue({ exec: vi.fn().mockResolvedValue({ _id: "r1" }) }) });
    await expect(rubricRepository.findDuplicate("g1", "abc")).resolves.toEqual({ _id: "r1" });
  });

  it("removes a rubric", async () => {
    modelMock.deleteOne.mockReturnValue({ exec: vi.fn().mockResolvedValue({ deletedCount: 1 }) });
    await expect(rubricRepository.remove("r1", "g1")).resolves.toBe(true);
  });

  it("returns false when remove misses", async () => {
    modelMock.deleteOne.mockReturnValue({ exec: vi.fn().mockResolvedValue({ deletedCount: 0 }) });
    await expect(rubricRepository.remove("r1", "g1")).resolves.toBe(false);
  });
});
