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

const ok = () => ({ status: vi.fn().mockReturnThis(), json: vi.fn().mockReturnThis() });

describe("analytics controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns the weekly summary", async () => {
    const summary = { weeks: [], totals: { created: 2, completed: 1 } };
    vi.mocked(analyticsService.getWeeklySummary).mockResolvedValue(summary as never);

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

    await analyticsController.weekly({ userId: "user-1", query: {} } as never, res as never, vi.fn() as never);

    expect(analyticsService.getWeeklySummary).toHaveBeenCalledWith("user-1", 8);
  });

  it("returns priority suggestions", async () => {
    const result = { suggestions: [] };
    vi.mocked(analyticsService.getPrioritySuggestions).mockResolvedValue(result as never);
    const res = ok();

    await analyticsController.prioritySuggestions(
      { userId: "user-1", query: { limit: 5 } } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.getPrioritySuggestions).toHaveBeenCalledWith("user-1", 5);
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Priority suggestions generated successfully.",
      data: result,
    });
  });

  it("applies priority suggestions", async () => {
    vi.mocked(analyticsService.applyPrioritySuggestions).mockResolvedValue({ updated: 2 });
    const res = ok();

    await analyticsController.applyPrioritySuggestions(
      { userId: "user-1" } as never,
      res as never,
      vi.fn() as never,
    );

    expect(analyticsService.applyPrioritySuggestions).toHaveBeenCalledWith("user-1");
    expect(res.status).toHaveBeenCalledWith(200);
    expect(res.json).toHaveBeenCalledWith({
      message: "Priority suggestions applied successfully.",
      data: { updated: 2 },
    });
  });

  it("rejects unauthenticated weekly summary requests", async () => {
    const res = ok();

    await analyticsController.weekly({ query: { weeks: 4 } } as never, res as never, vi.fn() as never);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(analyticsService.getWeeklySummary).not.toHaveBeenCalled();
  });

  it("propagates service errors", async () => {
    const error = new Error("boom");
    vi.mocked(analyticsService.getWeeklySummary).mockRejectedValue(error);
    const next = vi.fn();

    await analyticsController.weekly({ userId: "user-1", query: {} } as never, ok() as never, next as never);

    expect(next).toHaveBeenCalledWith(error);
  });
});
