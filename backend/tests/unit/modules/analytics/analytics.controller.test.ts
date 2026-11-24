import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/analytics/analytics.service.js", () => ({
  analyticsService: {
    getWeeklySummary: vi.fn(),
    getPrioritySuggestions: vi.fn(),
    applyPrioritySuggestions: vi.fn(),
  },
}));

import { analyticsController } from "../../../../src/modules/analytics/analytics.controller.js";
import { analyticsService } from "../../../../src/modules/analytics/analytics.service.js";

const ok = () => ({
  status: vi.fn().mockReturnThis(),
  json: vi.fn().mockReturnThis(),
});

describe("analytics controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns the weekly summary", async () => {
    const summary = { weeks: [], totals: { created: 2, completed: 1 } };
    vi.mocked(analyticsService.getWeeklySummary).mockResolvedValue(
      summary as never,
    );

    const res = ok();
    await analyticsController.weekly(
      { userId: "user-1", query: { weeks: 4 } } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.getWeeklySummary).toHaveBeenCalledWith("user-1", 4);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Weekly productivity summary retrieved successfully.",
      data: summary,
    });
  });

  it("applies a default of 8 weeks when the query is missing", async () => {
    vi.mocked(analyticsService.getWeeklySummary).mockResolvedValue({} as never);
    const res = ok();

    await analyticsController.weekly(
      { userId: "user-1", query: {} } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.getWeeklySummary).toHaveBeenCalledWith("user-1", 8);
  });

  it("returns priority suggestions", async () => {
    const result = { suggestions: [] };
    vi.mocked(analyticsService.getPrioritySuggestions).mockResolvedValue(
      result as never,
    );
    const res = ok();

    await analyticsController.prioritySuggestions(
      { userId: "user-1", query: { limit: 5 } } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.getPrioritySuggestions).toHaveBeenCalledWith(
      "user-1",
      5,
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Priority suggestions generated successfully.",
      data: result,
    });
  });

  it("applies priority suggestions", async () => {
    vi.mocked(analyticsService.applyPrioritySuggestions).mockResolvedValue({
      updated: 2,
    });
    const res = ok();

    await analyticsController.applyPrioritySuggestions(
      { userId: "user-1" } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.applyPrioritySuggestions).toHaveBeenCalledWith(
      "user-1",
    );
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Priority suggestions applied successfully.",
      data: { updated: 2 },
    });
  });

  it("rejects unauthenticated weekly summary requests", async () => {
    const res = ok();

    await analyticsController.weekly(
      { query: { weeks: 4 } } as never,
      res as never,
      vi.fn() as never,
    );

    expect(res.status).toHaveBeenCalledWith(401);
    expect(analyticsService.getWeeklySummary).not.toHaveBeenCalled();
  });

  it("rejects unauthenticated priority and apply requests", async () => {
    const res1 = ok();
    await analyticsController.prioritySuggestions(
      { query: {} } as never,
      res1 as never,
      vi.fn() as never,
    );
    expect(res1.status).toHaveBeenCalledWith(401);

    const res2 = ok();
    await analyticsController.applyPrioritySuggestions(
      {} as never,
      res2 as never,
      vi.fn() as never,
    );
    expect(res2.status).toHaveBeenCalledWith(401);
  });

  it("propagates service errors", async () => {
    const error = new Error("boom");
    vi.mocked(analyticsService.getWeeklySummary).mockRejectedValue(error);
    const next = vi.fn();

    await analyticsController.weekly(
      { userId: "user-1", query: {} } as never,
      ok() as never,
      next as never,
    );

    expect(next).toHaveBeenCalledWith(error);
  });

  it("propagates priority suggestion and apply errors", async () => {
    const error = new Error("boom");
    vi.mocked(analyticsService.getPrioritySuggestions).mockRejectedValue(error);
    vi.mocked(analyticsService.applyPrioritySuggestions).mockRejectedValue(
      error,
    );
    const next1 = vi.fn();
    await analyticsController.prioritySuggestions(
      { userId: "user-1", query: {} } as never,
      ok() as never,
      next1 as never,
    );
    expect(next1).toHaveBeenCalledWith(error);

    const next2 = vi.fn();
    await analyticsController.applyPrioritySuggestions(
      { userId: "user-1" } as never,
      ok() as never,
      next2 as never,
    );
    expect(next2).toHaveBeenCalledWith(error);
  });
});
