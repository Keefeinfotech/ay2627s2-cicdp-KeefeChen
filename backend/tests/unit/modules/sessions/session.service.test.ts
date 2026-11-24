import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  findById: vi.fn(),
  listByGroup: vi.fn(),
  update: vi.fn(),
  join: vi.fn(),
  leave: vi.fn(),
  remove: vi.fn(),
  requireGroupMembership: vi.fn(),
  auditRecord: vi.fn(),
}));

vi.mock("../../../../src/modules/sessions/session.repository.js", () => ({
  sessionRepository: {
    create: mocks.create,
    findById: mocks.findById,
    listByGroup: mocks.listByGroup,
    update: mocks.update,
    join: mocks.join,
    leave: mocks.leave,
    remove: mocks.remove,
  },
}));

vi.mock("../../../../src/modules/groups/shared/membership.js", () => ({
  GROUP_MANAGER_ROLES: ["owner", "admin"],
  requireGroupMembership: mocks.requireGroupMembership,
}));

vi.mock("../../../../src/modules/audit/audit.service.js", () => ({
  auditService: { record: mocks.auditRecord },
}));

import { sessionService } from "../../../../src/modules/sessions/session.service.js";

const baseSession = {
  _id: "s1",
  groupId: "g1",
  createdBy: "u1",
  status: "scheduled",
  startsAt: new Date("2026-01-01T10:00:00Z"),
  endsAt: new Date("2026-01-01T11:00:00Z"),
  attendeeIds: ["u1"],
  maxAttendees: null,
};

describe("sessionService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.requireGroupMembership.mockResolvedValue({ role: "member" });
    mocks.auditRecord.mockResolvedValue(undefined);
  });

  it("creates a session", async () => {
    mocks.create.mockResolvedValue({ ...baseSession });
    const res = await sessionService.create("g1", "u1", {
      title: "Study",
      startsAt: new Date("2026-01-01T10:00:00Z"),
      endsAt: new Date("2026-01-01T11:00:00Z"),
    } as never);
    expect(mocks.create).toHaveBeenCalled();
    expect(res._id).toBe("s1");
  });

  it("rejects invalid session range on create", async () => {
    await expect(
      sessionService.create("g1", "u1", {
        title: "T",
        startsAt: new Date("2026-01-01T11:00:00Z"),
        endsAt: new Date("2026-01-01T10:00:00Z"),
      } as never),
    ).rejects.toMatchObject({ code: "INVALID_SESSION_RANGE" });
  });

  it("lists sessions", async () => {
    mocks.listByGroup.mockResolvedValue({ items: [], pagination: {} });
    await sessionService.list("g1", "u1", { page: 1, limit: 10 } as never);
    expect(mocks.listByGroup).toHaveBeenCalledWith(
      "g1",
      expect.objectContaining({ page: 1, limit: 10 }),
    );
  });

  it("gets a session", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    await expect(sessionService.get("g1", "u1", "s1")).resolves.toEqual(
      baseSession,
    );
  });

  it("throws when session not found", async () => {
    mocks.findById.mockResolvedValue(null);
    await expect(sessionService.get("g1", "u1", "s1")).rejects.toMatchObject({
      code: "SESSION_NOT_FOUND",
    });
  });

  it("throws when session belongs to another group", async () => {
    mocks.findById.mockResolvedValue({ ...baseSession, groupId: "g2" });
    await expect(sessionService.get("g1", "u1", "s1")).rejects.toMatchObject({
      code: "SESSION_NOT_FOUND",
    });
  });

  it("updates a session as creator", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    mocks.update.mockResolvedValue({ ...baseSession, title: "N" });
    const res = await sessionService.update("g1", "u1", "s1", {
      title: " New ",
    } as never);
    expect(res.title).toBe("N");
  });

  it("rejects update by non-creator non-manager", async () => {
    mocks.findById.mockResolvedValue({ ...baseSession, createdBy: "other" });
    mocks.requireGroupMembership.mockResolvedValue({ role: "member" });
    await expect(
      sessionService.update("g1", "u1", "s1", { title: "X" } as never),
    ).rejects.toMatchObject({ code: "SESSION_UPDATE_FORBIDDEN" });
  });

  it("rejects update with invalid range", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    await expect(
      sessionService.update("g1", "u1", "s1", {
        startsAt: new Date("2026-01-01T12:00:00Z"),
        endsAt: new Date("2026-01-01T11:00:00Z"),
      } as never),
    ).rejects.toMatchObject({ code: "INVALID_SESSION_RANGE" });
  });

  it("cancels a scheduled session", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    mocks.update.mockResolvedValue({ ...baseSession, status: "cancelled" });
    const res = await sessionService.cancel("g1", "u1", "s1");
    expect(res.status).toBe("cancelled");
  });

  it("rejects cancelling non-scheduled session", async () => {
    mocks.findById.mockResolvedValue({ ...baseSession, status: "completed" });
    await expect(sessionService.cancel("g1", "u1", "s1")).rejects.toMatchObject(
      { code: "SESSION_NOT_SCHEDULABLE" },
    );
  });

  it("completes a scheduled session", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    mocks.update.mockResolvedValue({ ...baseSession, status: "completed" });
    const res = await sessionService.complete("g1", "u1", "s1");
    expect(res.status).toBe("completed");
  });

  it("joins a session", async () => {
    mocks.findById.mockResolvedValue({ ...baseSession, attendeeIds: [] });
    mocks.join.mockResolvedValue({ ...baseSession, attendeeIds: ["u1"] });
    const res = await sessionService.join("g1", "u1", "s1");
    expect(res.attendeeIds).toContain("u1");
  });

  it("returns existing session when already joined", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    const res = await sessionService.join("g1", "u1", "s1");
    expect(res).toEqual(baseSession);
    expect(mocks.join).not.toHaveBeenCalled();
  });

  it("rejects joining full session", async () => {
    mocks.findById.mockResolvedValue({
      ...baseSession,
      attendeeIds: ["u2"],
      maxAttendees: 1,
    });
    mocks.join.mockResolvedValue(null);
    await expect(sessionService.join("g1", "u1", "s1")).rejects.toMatchObject({
      code: "SESSION_FULL",
    });
  });

  it("leaves a session", async () => {
    mocks.leave.mockResolvedValue({ ...baseSession, attendeeIds: [] });
    const res = await sessionService.leave("g1", "u1", "s1");
    expect(res.attendeeIds).toEqual([]);
  });

  it("throws when leaving missing/non-attending session", async () => {
    mocks.leave.mockResolvedValue(null);
    await expect(sessionService.leave("g1", "u1", "s1")).rejects.toMatchObject({
      code: "SESSION_NOT_FOUND",
    });
  });

  it("deletes a session as creator", async () => {
    mocks.findById.mockResolvedValue(baseSession);
    mocks.remove.mockResolvedValue(true);
    await expect(
      sessionService.delete("g1", "u1", "s1"),
    ).resolves.toBeUndefined();
  });

  it("rejects delete by non-creator non-manager", async () => {
    mocks.findById.mockResolvedValue({ ...baseSession, createdBy: "other" });
    await expect(sessionService.delete("g1", "u1", "s1")).rejects.toMatchObject(
      { code: "SESSION_UPDATE_FORBIDDEN" },
    );
  });
});
