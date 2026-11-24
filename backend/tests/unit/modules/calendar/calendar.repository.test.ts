import { beforeEach, describe, expect, it, vi } from "vitest";

const { modelMock, saveMock } = vi.hoisted(() => {
  const save = vi.fn();
  const model: any = vi.fn().mockImplementation(function (
    this: any,
    data: any,
  ) {
    Object.assign(this, data);
    this.save = save;
  });
  model.findById = vi.fn();
  model.find = vi.fn();
  model.findOneAndUpdate = vi.fn();
  model.deleteOne = vi.fn();
  return { modelMock: model, saveMock: save };
});

vi.mock("../../../../src/modules/calendar/calendar.model.js", () => ({
  CalendarEventModel: modelMock,
  EventPriority: { LOW: "LOW", MEDIUM: "MEDIUM", HIGH: "HIGH" },
  EventStatus: { SCHEDULED: "SCHEDULED", CANCELLED: "CANCELLED" },
}));

import { CalendarRepository } from "../../../../src/modules/calendar/calendar.repository.js";

const chain = (value: unknown) => {
  const q: any = { exec: vi.fn().mockResolvedValue(value) };
  q.sort = vi.fn().mockReturnValue(q);
  return q;
};

describe("CalendarRepository", () => {
  let repo: CalendarRepository;
  const uid = "11111111-1111-1111-1111-111111111111";

  beforeEach(() => {
    vi.clearAllMocks();
    repo = new CalendarRepository();
  });

  it("creates an event", async () => {
    saveMock.mockResolvedValue({ _id: "e1" });
    const res = await repo.create("u1", {
      title: "T",
      startTime: new Date(),
      endTime: new Date(),
      groupId: uid,
      taskId: uid,
    } as never);
    expect(modelMock).toHaveBeenCalled();
    expect(saveMock).toHaveBeenCalled();
    expect(res).toEqual({ _id: "e1" });
  });

  it("rejects invalid groupId on create", async () => {
    await expect(
      repo.create("u1", { title: "T", groupId: "bad" } as never),
    ).rejects.toThrow("Invalid groupId");
  });

  it("finds by id", async () => {
    modelMock.findById.mockReturnValue(chain({ _id: "e1" }));
    await expect(repo.findById("e1")).resolves.toEqual({ _id: "e1" });
  });

  it("finds by range with group filter", async () => {
    modelMock.find.mockReturnValue(chain([{ _id: "e1" }]));
    const res = await repo.findByRange(
      "u1",
      new Date("2026-01-01"),
      new Date("2026-01-31"),
      uid,
    );
    expect(modelMock.find).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "u1", groupId: uid }),
    );
    expect(res).toHaveLength(1);
  });

  it("rejects invalid groupId in range query", async () => {
    await expect(
      repo.findByRange("u1", new Date(), new Date(), "bad"),
    ).rejects.toThrow("Invalid groupId");
  });

  it("updates only allowed fields", async () => {
    modelMock.findOneAndUpdate.mockReturnValue(
      chain({ _id: "e1", title: "N" }),
    );
    const res = await repo.update("e1", "u1", {
      title: "N",
      evil: "x",
    } as never);
    expect(modelMock.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: "e1", userId: "u1" },
      { $set: { title: "N" } },
      { new: true },
    );
    expect(res).toEqual({ _id: "e1", title: "N" });
  });

  it("deletes an event", async () => {
    modelMock.deleteOne.mockReturnValue(chain({ deletedCount: 1 }));
    await expect(repo.delete("e1", "u1")).resolves.toBe(true);
  });

  it("returns false when delete misses", async () => {
    modelMock.deleteOne.mockReturnValue(chain({ deletedCount: 0 }));
    await expect(repo.delete("e1", "u1")).resolves.toBe(false);
  });

  it("finds overlapping events with exclusion", async () => {
    modelMock.find.mockReturnValue(chain([{ _id: "e2" }]));
    const res = await repo.findOverlapping(
      "u1",
      new Date("2026-01-01T10:00:00Z"),
      new Date("2026-01-01T11:00:00Z"),
      "507f1f77bcf86cd799439011",
    );
    expect(modelMock.find).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "u1" }),
    );
    expect(res).toHaveLength(1);
  });

  it("rejects invalid excludeEventId", async () => {
    await expect(
      repo.findOverlapping("u1", new Date(), new Date(), "bad-id"),
    ).rejects.toThrow("Invalid excludeEventId");
  });
});
