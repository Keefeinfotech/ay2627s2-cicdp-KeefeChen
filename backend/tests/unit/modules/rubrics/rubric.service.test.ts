import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  requireGroupRole: vi.fn(),
  requireGroupMembership: vi.fn(),
  findDuplicate: vi.fn(),
  create: vi.fn(),
  listByGroup: vi.fn(),
  findById: vi.fn(),
  remove: vi.fn(),
  auditRecord: vi.fn(),
  roadmapCreateFromRubric: vi.fn(),
}));

vi.mock("../../../../src/modules/groups/shared/membership.js", () => ({
  GROUP_MANAGER_ROLES: ["owner", "admin"],
  requireGroupRole: mocks.requireGroupRole,
  requireGroupMembership: mocks.requireGroupMembership,
}));

vi.mock("../../../../src/modules/rubrics/rubric.repository.js", () => ({
  rubricRepository: {
    findDuplicate: mocks.findDuplicate,
    create: mocks.create,
    listByGroup: mocks.listByGroup,
    findById: mocks.findById,
    remove: mocks.remove,
  },
}));

vi.mock("../../../../src/modules/audit/audit.service.js", () => ({
  auditService: { record: mocks.auditRecord },
}));

vi.mock("../../../../src/modules/roadmaps/roadmap.service.js", () => ({
  roadmapService: { createFromRubric: mocks.roadmapCreateFromRubric },
}));

import { parseCriteria, rubricService } from "../../../../src/modules/rubrics/rubric.service.js";

describe("parseCriteria", () => {
  it("parses piped criteria and normalizes weights", () => {
    const result = parseCriteria("Structure | 30 | clear\nContent | 70 | deep");
    expect(result).toEqual([
      { name: "Structure", description: "clear", weight: 30 },
      { name: "Content", description: "deep", weight: 70 },
    ]);
  });

  it("parses percentage shapes and plain lines", () => {
    const result = parseCriteria("Clarity (40%)\nDepth - 60%");
    expect(result).toHaveLength(2);
    expect(result[0].weight + result[1].weight).toBeCloseTo(100);
  });

  it("assigns equal weights when none declared", () => {
    const result = parseCriteria("Clarity\nDepth\nStyle");
    expect(result.map((r) => r.weight)).toEqual([33.33, 33.33, 33.33]);
  });

  it("ignores heading noise and keeps declared partial weights", () => {
    const result = parseCriteria("Rubric\nClarity | 30\nDepth");
    expect(result).toEqual([
      { name: "Clarity", description: null, weight: 30 },
      { name: "Depth", description: null, weight: 0 },
    ]);
  });
});

describe("rubricService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireGroupRole.mockResolvedValue({ role: "owner" });
    mocks.requireGroupMembership.mockResolvedValue({ role: "member" });
    mocks.auditRecord.mockResolvedValue(undefined);
  });

  it("creates a rubric and records audit", async () => {
    mocks.findDuplicate.mockResolvedValue(null);
    mocks.create.mockResolvedValue({ _id: "r1", criteria: [{ name: "Clarity", weight: 100 }] });

    const res = await rubricService.create("g1", "u1", { title: "Rubric", sourceText: "Clarity | 100" });

    expect(mocks.create).toHaveBeenCalled();
    expect(mocks.auditRecord).toHaveBeenCalledWith(expect.objectContaining({ action: expect.any(String) }));
    expect(res._id).toBe("r1");
  });

  it("returns duplicate rubric if checksum matches", async () => {
    mocks.findDuplicate.mockResolvedValue({ _id: "existing" });
    const res = await rubricService.create("g1", "u1", { title: "R", sourceText: "Clarity | 100" });
    expect(res).toEqual({ _id: "existing" });
    expect(mocks.create).not.toHaveBeenCalled();
  });

  it("throws when no criteria parsed", async () => {
    await expect(rubricService.create("g1", "u1", { title: "R", sourceText: "   " })).rejects.toMatchObject({ code: "RUBRIC_NO_CRITERIA" });
  });

  it("lists rubrics", async () => {
    mocks.listByGroup.mockResolvedValue({ items: [], pagination: {} });
    await rubricService.list("g1", "u1", { page: 2, limit: 5 });
    expect(mocks.listByGroup).toHaveBeenCalledWith("g1", 2, 5);
  });

  it("gets a rubric", async () => {
    mocks.findById.mockResolvedValue({ _id: "r1", groupId: "g1" });
    await expect(rubricService.get("g1", "u1", "r1")).resolves.toEqual({ _id: "r1", groupId: "g1" });
  });

  it("throws when rubric missing or wrong group", async () => {
    mocks.findById.mockResolvedValue({ _id: "r1", groupId: "g2" });
    await expect(rubricService.get("g1", "u1", "r1")).rejects.toMatchObject({ code: "RUBRIC_NOT_FOUND" });
  });

  it("creates a roadmap proposal from a rubric", async () => {
    mocks.findById.mockResolvedValue({ _id: "r1", groupId: "g1", title: "R", criteria: [{ name: "A", description: null, weight: 100 }] });
    mocks.roadmapCreateFromRubric.mockResolvedValue({ _id: "road-1", status: "draft", items: [1, 2] });
    const res = await rubricService.createRoadmapProposal("g1", "u1", "r1");
    expect(res.proposal).toEqual({ roadmapId: "road-1", draftStatus: "draft", itemCount: 2 });
  });

  it("deletes a rubric", async () => {
    mocks.remove.mockResolvedValue(true);
    await expect(rubricService.delete("g1", "u1", "r1")).resolves.toBeUndefined();
    expect(mocks.auditRecord).toHaveBeenCalled();
  });

  it("throws when deleting missing rubric", async () => {
    mocks.remove.mockResolvedValue(false);
    await expect(rubricService.delete("g1", "u1", "r1")).rejects.toMatchObject({ code: "RUBRIC_NOT_FOUND" });
  });
});
