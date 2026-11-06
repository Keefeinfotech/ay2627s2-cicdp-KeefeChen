import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  requireGroupMembership: vi.fn(),
  memberFind: vi.fn(),
  roadmapFind: vi.fn(),
  sessionFind: vi.fn(),
}));

vi.mock("../../../../src/modules/groups/shared/membership.js", () => ({
  requireGroupMembership: mocks.requireGroupMembership,
}));
vi.mock("../../../../src/modules/groups/member/member.model.js", () => ({
  Member: {
    find: mocks.memberFind,
  },
}));
vi.mock("../../../../src/modules/roadmaps/roadmap.model.js", () => ({
  Roadmap: {
    find: mocks.roadmapFind,
  },
}));
vi.mock("../../../../src/modules/sessions/session.model.js", () => ({
  StudySession: {
    find: mocks.sessionFind,
  },
}));

import { progressService } from "../../../../src/modules/progress/progress.service.js";

const queryWithRows = (rows: unknown[]) => ({
  select: vi.fn().mockReturnValue({
    lean: vi.fn().mockResolvedValue(rows),
  }),
});

describe("progress service", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireGroupMembership.mockResolvedValue({
      groupId: "group-1",
      userId: "user-1",
      role: "OWNER",
      status: "ACTIVE",
    });
  });

  it("aggregates membership, roadmap and session progress", async () => {
    mocks.memberFind.mockReturnValue(
      queryWithRows([
        { role: "OWNER" },
        { role: "ADMIN" },
        { role: "MEMBER" },
        { role: "MEMBER" },
      ]),
    );
    mocks.roadmapFind.mockReturnValue(
      queryWithRows([
        {
          status: "approved",
          items: [
            { status: "done" },
            { status: "in_progress" },
            { status: "pending" },
          ],
        },
        {
          status: "draft",
          items: [{ status: "done" }],
        },
      ]),
    );
    mocks.sessionFind.mockReturnValue(
      queryWithRows([
        { status: "scheduled", startsAt: new Date("2099-01-01T00:00:00Z") },
        { status: "completed", startsAt: new Date("2026-01-01T00:00:00Z") },
        { status: "cancelled", startsAt: new Date("2026-01-02T00:00:00Z") },
      ]),
    );

    const result = await progressService.get("group-1", "user-1");

    expect(mocks.requireGroupMembership).toHaveBeenCalledWith(
      "group-1",
      "user-1",
    );
    expect(result.members).toEqual({
      total: 4,
      owners: 1,
      admins: 1,
      members: 2,
    });
    expect(result.roadmaps).toMatchObject({
      total: 2,
      approved: 1,
      completionPercent: 50,
      items: {
        total: 4,
        done: 2,
        inProgress: 1,
        pending: 1,
      },
    });
    expect(result.sessions).toEqual({
      total: 3,
      upcoming: 1,
      completed: 1,
      cancelled: 1,
    });
  });

  it("returns zero completion for a group without roadmap items", async () => {
    mocks.memberFind.mockReturnValue(queryWithRows([]));
    mocks.roadmapFind.mockReturnValue(queryWithRows([]));
    mocks.sessionFind.mockReturnValue(queryWithRows([]));

    const result = await progressService.get("group-1", "user-1");

    expect(result.roadmaps.completionPercent).toBe(0);
    expect(result.roadmaps.items.total).toBe(0);
  });
});
