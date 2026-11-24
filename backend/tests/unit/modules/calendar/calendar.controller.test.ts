import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  createEvent: vi.fn(),
  getEventsForPeriod: vi.fn(),
  updateEvent: vi.fn(),
  deleteEvent: vi.fn(),
  checkConflicts: vi.fn(),
}));

vi.mock("../../../../src/modules/calendar/calendar.service.js", () => ({
  CalendarService: vi.fn().mockImplementation(function (this: unknown) {
    return {
      createEvent: mocks.createEvent,
      getEventsForPeriod: mocks.getEventsForPeriod,
      updateEvent: mocks.updateEvent,
      deleteEvent: mocks.deleteEvent,
      checkConflicts: mocks.checkConflicts,
    };
  }),
}));

import { CalendarController } from "../../../../src/modules/calendar/calendar.controller.js";

const ok = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() });

describe("CalendarController", () => {
  let controller: CalendarController;

  beforeEach(() => {
    vi.clearAllMocks();
    controller = new CalendarController();
  });

  it("creates an event for the authenticated user", async () => {
    const event = { id: "ev-1" };
    mocks.createEvent.mockResolvedValue(event);
    const res = ok();

    await controller.createEvent({ userId: "u1", body: { title: "T" } } as never, res as never, vi.fn() as never);

    expect(mocks.createEvent).toHaveBeenCalledWith("u1", { title: "T" });
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: event });
  });

  it("rejects create when unauthenticated", async () => {
    const res = ok();
    await controller.createEvent({ body: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("maps validation-like create errors to 400", async () => {
    const err = Object.assign(new Error("bad"), { name: "ValidationError" });
    mocks.createEvent.mockRejectedValue(err);
    const res = ok();

    await controller.createEvent({ userId: "u1", body: {} } as never, res as never, vi.fn() as never);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ success: false, message: "bad" });
  });

  it("forwards unexpected create errors", async () => {
    const err = new Error("boom");
    mocks.createEvent.mockRejectedValue(err);
    const next = vi.fn();
    await controller.createEvent({ userId: "u1", body: {} } as never, ok() as never, next as never);
    expect(next).toHaveBeenCalledWith(err);
  });

  it("lists events for a valid range", async () => {
    const events = [{ id: "ev-1" }];
    mocks.getEventsForPeriod.mockResolvedValue(events);
    const res = ok();

    await controller.getEvents(
      { userId: "u1", query: { startDate: "2026-01-01", endDate: "2026-01-31", groupId: "g1" } } as never,
      res as never,
      vi.fn() as never,
    );

    expect(mocks.getEventsForPeriod).toHaveBeenCalledWith("u1", expect.any(Date), expect.any(Date), "g1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, data: events });
  });

  it("rejects getEvents without required query params", async () => {
    const res = ok();
    await controller.getEvents({ userId: "u1", query: { startDate: "2026-01-01" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("rejects getEvents with invalid dates", async () => {
    const res = ok();
    await controller.getEvents({ userId: "u1", query: { startDate: "bad", endDate: "also-bad" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: false }));
  });

  it("rejects getEvents when unauthenticated", async () => {
    const res = ok();
    await controller.getEvents({ query: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it("updates an event", async () => {
    mocks.updateEvent.mockResolvedValue({ id: "ev-1", title: "N" });
    const res = ok();
    await controller.updateEvent({ userId: "u1", params: { id: "ev-1" }, body: { title: "N" } } as never, res as never, vi.fn() as never);
    expect(mocks.updateEvent).toHaveBeenCalledWith("ev-1", "u1", { title: "N" });
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("returns 404 when update target is missing/unauthorized", async () => {
    mocks.updateEvent.mockRejectedValue(new Error("Calendar event not found or unauthorized"));
    const res = ok();
    await controller.updateEvent({ userId: "u1", params: { id: "ev-1" }, body: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("rejects update without id", async () => {
    const res = ok();
    await controller.updateEvent({ userId: "u1", params: {}, body: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("deletes an event", async () => {
    mocks.deleteEvent.mockResolvedValue(true);
    const res = ok();
    await controller.deleteEvent({ userId: "u1", params: { id: "ev-1" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({ success: true, message: "Event deleted successfully" });
  });

  it("returns 404 when delete fails", async () => {
    mocks.deleteEvent.mockResolvedValue(false);
    const res = ok();
    await controller.deleteEvent({ userId: "u1", params: { id: "ev-1" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it("checks schedule conflicts", async () => {
    mocks.checkConflicts.mockResolvedValue({ hasConflict: true, conflictingEvents: [{ id: "ev-2" }] });
    const res = ok();
    await controller.checkScheduleConflicts(
      { userId: "u1", query: { startTime: "2026-01-01T10:00:00Z", endTime: "2026-01-01T11:00:00Z", excludeId: "ev-1" } } as never,
      res as never,
      vi.fn() as never,
    );
    expect(mocks.checkConflicts).toHaveBeenCalledWith("u1", expect.any(Date), expect.any(Date), "ev-1");
    expect(res.status).toHaveBeenCalledWith(200);
  });

  it("rejects conflict check without times", async () => {
    const res = ok();
    await controller.checkScheduleConflicts({ userId: "u1", query: {} } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it("rejects conflict check with invalid dates", async () => {
    const res = ok();
    await controller.checkScheduleConflicts({ userId: "u1", query: { startTime: "x", endTime: "y" } } as never, res as never, vi.fn() as never);
    expect(res.status).toHaveBeenCalledWith(400);
  });
});
