import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const find = vi.fn();
  const countDocuments = vi.fn();
  const aggregate = vi.fn();
  const updateOne = vi.fn();
  return {
    find,
    countDocuments,
    aggregate,
    updateOne,
    Task: { find, countDocuments, aggregate, updateOne },
  };
});

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: mocks.Task,
}));

vi.mock("../../../../src/shared/utils/cache.js", () => ({
  cacheGetJson: vi.fn().mockResolvedValue(null),
  cacheSetJson: vi.fn().mockResolvedValue(undefined),
}));

import { analyticsService } from "../../../../src/modules/analytics/analytics.service.js";

const chain = (value: unknown) => {
  const query: Record<string, unknown> = {};
  for (const method of ["select", "sort", "limit", "skip", "lean"]) {
    query[method] = vi.fn().mockReturnValue(query);
  }
  query.lean = vi.fn().mockResolvedValue(value);
  return query;
};

describe("analytics read endpoints", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("builds an overview with a completion rate", async () => {
    mocks.countDocuments
      .mockResolvedValueOnce(10)
      .mockResolvedValueOnce(4)
      .mockResolvedValueOnce(2)
      .mockResolvedValueOnce(3)
      .mockResolvedValueOnce(2);

    const result = await analyticsService.getOverview("user-1");
    expect(result).toMatchObject({
      totalTasks: 10,
      active: 6,
      completed: 4,
      overdueOpen: 2,
      completionRate: 0.4,
    });
  });

  it("handles an empty overview", async () => {
    mocks.countDocuments.mockResolvedValue(0);
    await expect(analyticsService.getOverview("user-1")).resolves.toMatchObject(
      {
        completionRate: 0,
      },
    );
  });

  it("returns one bucket per day and per month", async () => {
    const today = new Date().toISOString().slice(0, 10);
    const month = today.slice(0, 7);
    mocks.aggregate
      .mockResolvedValueOnce([{ _id: today, count: 2 }])
      .mockResolvedValueOnce([{ _id: today, count: 1 }]);
    const daily = await analyticsService.getDaily("user-1", 3);
    expect(daily).toHaveLength(3);
    expect(daily[2]).toMatchObject({ created: 2, completed: 1 });

    mocks.aggregate
      .mockResolvedValueOnce([{ _id: month, count: 5 }])
      .mockResolvedValueOnce([{ _id: month, count: 3 }]);
    const monthly = await analyticsService.getMonthly("user-1", 2);
    expect(monthly).toHaveLength(2);
    expect(monthly[1]).toMatchObject({ created: 5, completed: 3 });
  });

  it("clamps invalid and oversized ranges", async () => {
    mocks.aggregate.mockResolvedValue([]);
    await expect(analyticsService.getDaily("user-1", 0)).resolves.toHaveLength(
      14,
    );
    await expect(
      analyticsService.getMonthly("user-1", 999),
    ).resolves.toHaveLength(24);
  });

  it("lists overdue tasks with a day count", async () => {
    mocks.find.mockReturnValue(
      chain([
        {
          _id: "task-1",
          title: "Late task",
          priority: "high",
          dueDate: new Date(Date.now() - 2 * 86400000),
        },
      ]),
    );
    const result = await analyticsService.getOverdue("user-1", 10);
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({ taskId: "task-1", title: "Late task" });
    expect(result[0].daysOverdue).toBeGreaterThanOrEqual(1);
  });

  it("computes completion rate and productivity summary", async () => {
    vi.spyOn(analyticsService, "getWeeklySummary").mockResolvedValue({
      weeks: [],
      totals: { created: 10, completed: 5, completionRate: 50 },
      currentStreakDays: 3,
      longestStreakDays: 7,
    } as never);
    vi.spyOn(analyticsService, "getOverview").mockResolvedValue({
      totalTasks: 10,
    } as never);

    await expect(
      analyticsService.getCompletionRate("user-1", 4),
    ).resolves.toMatchObject({
      rate: 50,
      completed: 5,
    });
    await expect(
      analyticsService.getProductivitySummary("user-1"),
    ).resolves.toMatchObject({ streakDays: 3 });
  });

  it("derives a trend direction from monthly buckets", async () => {
    const monthly = [
      { month: "2026-10", created: 3, completed: 1 },
      { month: "2026-11", created: 3, completed: 4 },
    ];
    vi.spyOn(analyticsService, "getMonthly")
      .mockResolvedValueOnce(monthly)
      .mockResolvedValueOnce([...monthly].reverse())
      .mockResolvedValueOnce(monthly.slice(0, 1));

    await expect(
      analyticsService.getTaskTrends("user-1", 2),
    ).resolves.toMatchObject({
      direction: "improving",
    });
    await expect(
      analyticsService.getTaskTrends("user-1", 2),
    ).resolves.toMatchObject({
      direction: "declining",
    });
    await expect(
      analyticsService.getTaskTrends("user-1", 1),
    ).resolves.toMatchObject({
      direction: "steady",
    });
  });
});
