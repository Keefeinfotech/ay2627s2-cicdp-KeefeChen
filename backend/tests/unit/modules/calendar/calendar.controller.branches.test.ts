import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createEvent: vi.fn(), getEventsForPeriod: vi.fn(), updateEvent: vi.fn(), deleteEvent: vi.fn(), checkConflicts: vi.fn(),
}));
vi.mock("../../../../src/modules/calendar/calendar.service.js", () => ({
  CalendarService: vi.fn().mockImplementation(function () { return mocks; }),
}));
import { CalendarController } from "../../../../src/modules/calendar/calendar.controller.js";

const ok = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() });
const run = async (ctrl: CalendarController, fn: keyof CalendarController, req: any) => {
  const res = ok(); const next = vi.fn();
  await (ctrl[fn] as any)(req, res, next);
  return { res, next };
};

describe("CalendarController branches", () => {
  let c: CalendarController;
  beforeEach(() => { vi.clearAllMocks(); c = new CalendarController(); });

  it("unauth on update/delete/conflicts", async () => {
    for (const [fn, req] of [["updateEvent", { params: { id: "1" }, body: {} }], ["deleteEvent", { params: { id: "1" } }], ["checkScheduleConflicts", { query: {} }]] as any[]) {
      const { res } = await run(c, fn, req);
      expect(res.status).toHaveBeenCalledWith(401);
    }
  });

  it("getEvents forwards service error", async () => {
    mocks.getEventsForPeriod.mockRejectedValue(new Error("boom"));
    const { next } = await run(c, "getEvents", { userId: "u1", query: { startDate: "2026-01-01", endDate: "2026-01-02" } });
    expect(next).toHaveBeenCalled();
  });

  it("updateEvent forwards unexpected error", async () => {
    mocks.updateEvent.mockRejectedValue(new Error("boom"));
    const { next } = await run(c, "updateEvent", { userId: "u1", params: { id: "1" }, body: {} });
    expect(next).toHaveBeenCalled();
  });

  it("deleteEvent unauth and missing id and next error", async () => {
    let out = await run(c, "deleteEvent", { userId: "u1", params: {} });
    expect(out.res.status).toHaveBeenCalledWith(400);
    mocks.deleteEvent.mockRejectedValue(new Error("boom"));
    out = await run(c, "deleteEvent", { userId: "u1", params: { id: "1" } });
    expect(out.next).toHaveBeenCalled();
  });

  it("checkScheduleConflicts forwards error", async () => {
    mocks.checkConflicts.mockRejectedValue(new Error("boom"));
    const { next } = await run(c, "checkScheduleConflicts", { userId: "u1", query: { startTime: "2026-01-01T10:00:00Z", endTime: "2026-01-01T11:00:00Z" } });
    expect(next).toHaveBeenCalled();
  });

  it("getEvents accepts array query params", async () => {
    mocks.getEventsForPeriod.mockResolvedValue([]);
    const { res } = await run(c, "getEvents", { userId: "u1", query: { startDate: ["2026-01-01"], endDate: ["2026-01-02"], groupId: ["g1"] } });
    expect(res.status).toHaveBeenCalledWith(200);
  });
});
