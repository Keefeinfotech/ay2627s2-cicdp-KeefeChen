import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => ({
  create: vi.fn(),
  findById: vi.fn(),
  findByRange: vi.fn(),
  update: vi.fn(),
  delete: vi.fn(),
  findOverlapping: vi.fn(),
}));

vi.mock("../../../../src/modules/calendar/calendar.repository.js", () => ({
  CalendarRepository: vi.fn().mockImplementation(function (this: unknown) {
    return mocks;
  }),
}));

import { CalendarService } from "../../../../src/modules/calendar/calendar.service.js";

describe("CalendarService", () => {
  let service: CalendarService;

  beforeEach(() => {
    vi.clearAllMocks();
    service = new CalendarService();
  });

  it("creates events via repository", async () => {
    mocks.create.mockResolvedValue({ id: "ev-1" });
    await expect(service.createEvent("u1", { title: "T" } as never)).resolves.toEqual({ id: "ev-1" });
    expect(mocks.create).toHaveBeenCalledWith("u1", { title: "T" });
  });

  it("returns events for a period", async () => {
    const start = new Date("2026-01-01");
    const end = new Date("2026-01-31");
    mocks.findByRange.mockResolvedValue([{ id: "ev-1" }]);
    await expect(service.getEventsForPeriod("u1", start, end, "g1")).resolves.toEqual([{ id: "ev-1" }]);
    expect(mocks.findByRange).toHaveBeenCalledWith("u1", start, end, "g1");
  });

  it("updates an owned event", async () => {
    mocks.findById.mockResolvedValue({ id: "ev-1", userId: { toString: () => "u1" } });
    mocks.update.mockResolvedValue({ id: "ev-1", title: "N" });
    await expect(service.updateEvent("ev-1", "u1", { title: "N" } as never)).resolves.toEqual({ id: "ev-1", title: "N" });
  });

  it("throws when updating missing or foreign event", async () => {
    mocks.findById.mockResolvedValue({ id: "ev-1", userId: { toString: () => "u2" } });
    await expect(service.updateEvent("ev-1", "u1", {} as never)).rejects.toThrow("Calendar event not found or unauthorized");
  });

  it("throws when repository update returns null", async () => {
    mocks.findById.mockResolvedValue({ id: "ev-1", userId: { toString: () => "u1" } });
    mocks.update.mockResolvedValue(null);
    await expect(service.updateEvent("ev-1", "u1", {} as never)).rejects.toThrow("Failed to update event");
  });

  it("deletes an event", async () => {
    mocks.delete.mockResolvedValue(true);
    await expect(service.deleteEvent("ev-1", "u1")).resolves.toBe(true);
    expect(mocks.delete).toHaveBeenCalledWith("ev-1", "u1");
  });

  it("checks conflicts and reports result", async () => {
    const start = new Date("2026-01-01T10:00:00Z");
    const end = new Date("2026-01-01T11:00:00Z");
    mocks.findOverlapping.mockResolvedValue([{ id: "ev-2" }]);
    await expect(service.checkConflicts("u1", start, end, "ev-1")).resolves.toEqual({
      hasConflict: true,
      conflictingEvents: [{ id: "ev-2" }],
    });
  });

  it("reports no conflicts when none found", async () => {
    mocks.findOverlapping.mockResolvedValue([]);
    await expect(service.checkConflicts("u1", new Date(), new Date())).resolves.toEqual({
      hasConflict: false,
      conflictingEvents: [],
    });
  });
});
