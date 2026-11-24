import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  list: vi.fn(),
  get: vi.fn(),
  createRoadmapProposal: vi.fn(),
  delete: vi.fn(),
}));

vi.mock("../../../../src/modules/rubrics/rubric.service.js", () => ({
  rubricService: mocks,
}));

vi.mock("../../../../src/modules/rubrics/rubric.validation.js", () => ({
  parseRubricSchema: { shape: { body: { parse: vi.fn((v: unknown) => v) } } },
  listRubricsSchema: { shape: { query: { parse: vi.fn((v: unknown) => v) } } },
  rubricParamSchema: { shape: { params: { parse: vi.fn((v: unknown) => v) } } },
  rubricRoadmapProposalSchema: { shape: { params: { parse: vi.fn((v: unknown) => v) } } },
}));

import { rubricController } from "../../../../src/modules/rubrics/rubric.controller.js";

const ok = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis(), send: vi.fn().mockReturnThis() });

describe("rubricController", () => {
  beforeEach(() => vi.clearAllMocks());

  it("creates a rubric", async () => {
    mocks.create.mockResolvedValue({ _id: "r1" });
    const res = ok();
    await rubricController.create({ userId: "u1", params: { groupId: "g1" }, body: { title: "T", sourceText: "A | 100" } } as never, res as never, vi.fn() as never);
    expect(mocks.create).toHaveBeenCalledWith("g1", "u1", { title: "T", sourceText: "A | 100" });
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it("rejects unauthenticated create", async () => {
    const res = ok();
    await rubricController.create({ params: { groupId: "g1" }, body: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("lists rubrics", async () => {
    mocks.list.mockResolvedValue({ items: [{ _id: "r1" }], pagination: {} });
    const res = ok();
    await rubricController.list({ userId: "u1", params: { groupId: "g1" }, query: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("gets a rubric", async () => {
    mocks.get.mockResolvedValue({ _id: "r1" });
    const res = ok();
    await rubricController.get({ userId: "u1", params: { groupId: "g1", rubricId: "r1" } } as never, res as never, vi.fn() as never);
    expect(mocks.get).toHaveBeenCalledWith("g1", "u1", "r1");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("creates a roadmap proposal", async () => {
    mocks.createRoadmapProposal.mockResolvedValue({ rubricId: "r1", proposal: {} });
    const res = ok();
    await rubricController.createRoadmapProposal({ userId: "u1", params: { groupId: "g1", rubricId: "r1" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it("deletes a rubric", async () => {
    mocks.delete.mockResolvedValue(undefined);
    const res = ok();
    await rubricController.remove({ userId: "u1", params: { groupId: "g1", rubricId: "r1" } } as never, res as never, vi.fn() as never);
    expect(mocks.delete).toHaveBeenCalledWith("g1", "u1", "r1");
    expect(res.status).toHaveBeenCalledWith(204);
  });

  it("forwards errors", async () => {
    const err = new Error("boom");
    mocks.get.mockRejectedValue(err);
    const next = vi.fn();
    await rubricController.get({ userId: "u1", params: { groupId: "g1", rubricId: "r1" } } as never, ok() as never, next as never);
    expect(next).toHaveBeenCalledWith(err);
  });
});
