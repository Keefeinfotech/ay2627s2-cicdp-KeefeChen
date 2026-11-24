import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/calendar/calendar.model.js", () => ({
  CalendarEventModel: {
    create: vi.fn(),
    findById: vi.fn(),
    find: vi.fn(),
    findOneAndUpdate: vi.fn(),
    deleteOne: vi.fn(),
  },
}));

import { CalendarRepository } from "../../../../src/modules/calendar/calendar.repository.js";

describe("calendar repository", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("updates only whitelisted fields via $set (mass-assignment defence)", async () => {
    const { CalendarEventModel } =
      await import("../../../../src/modules/calendar/calendar.model.js");
    vi.mocked(CalendarEventModel.findOneAndUpdate).mockReturnValue({
      exec: async () => ({ _id: "event-1" }),
    } as any);

    await new CalendarRepository().update("event-1", "user-1", {
      title: "Renamed session",
    });

    expect(CalendarEventModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: "event-1", userId: "user-1" },
      { $set: { title: "Renamed session" } },
      { new: true },
    );
  });

  it("drops non-whitelisted fields (including identity/authority fields) on update", async () => {
    const { CalendarEventModel } =
      await import("../../../../src/modules/calendar/calendar.model.js");
    vi.mocked(CalendarEventModel.findOneAndUpdate).mockReturnValue({
      exec: async () => ({ _id: "event-1" }),
    } as any);

    await new CalendarRepository().update("event-1", "user-1", {
      title: "Renamed session",
      status: "CANCELLED",
      userId: "attacker-user-id",
      groupId: "attacker-group-id",
      taskId: "attacker-task-id",
      isAdmin: true,
    } as any);

    // Whitelisted fields are applied; everything else is ignored.
    expect(CalendarEventModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: "event-1", userId: "user-1" },
      { $set: { title: "Renamed session", status: "CANCELLED" } },
      { new: true },
    );
  });
});
