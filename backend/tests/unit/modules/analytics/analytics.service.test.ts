import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const find = vi.fn();
  const countDocuments = vi.fn();
  const updateOne = vi.fn();
  const cacheGetJson = vi.fn();
  const cacheSetJson = vi.fn();

  return {
    find,
    countDocuments,
    updateOne,
    cacheGetJson,
    cacheSetJson,
    Task: { find, countDocuments, updateOne },
  };
});

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: mocks.Task,
}));

vi.mock("../../../../src/shared/utils/cache.js", () => ({
  cacheGetJson: mocks.cacheGetJson,
  cacheSetJson: mocks.cacheSetJson,
  cacheDel: vi.fn(),
  cacheDelByPattern: vi.fn(),
}));

import { analyticsService } from "../../../../src/modules/analytics/analytics.service.js";

function leanQuery(result: unknown) {
  return {
    select: vi.fn().mockReturnThis(),
    lean: vi.fn().mockResolvedValue(result),
  };
}

const DAY = 24 * 60 * 60 * 1000;

describe("analyticsService.getWeeklySummary", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.cacheGetJson.mockResolvedValue(null);
    mocks.cacheSetJson.mockResolvedValue(undefined);
  });

  it("serves the summary from cache when available", async () => {
    const cached = { weeks: [], totals: { created: 0 } };
    mocks.cacheGetJson.mockResolvedValue(cached);

    await expect(
      analyticsService.getWeeklySummary("user-1", 4),
    ).resolves.toEqual(cached);

    expect(mocks.find).not.toHaveBeenCalled();
    expect(mocks.cacheSetJson).not.toHaveBeenCalled();
  });

  it("computes weekly buckets and totals", async () => {
    const now = new Date();
    mocks.find.mockImplementation((filter: unknown) => {
      const f = filter as Record<string, unknown>;
      if (f.createdAt) {
        return leanQuery([{ createdAt: new Date(now.getTime() - 2 * DAY) }]);
      }
      if (f.completedAt) {
        return leanQuery([]);
      }
      if (f.status) {
        // Overdue open tasks count query.
        return { select: vi.fn(), lean: vi.fn() };
      }
      return leanQuery([]);
    });
    mocks.countDocuments.mockResolvedValue(1);

    const summary = await analyticsService.getWeeklySummary("user-1", 2);

    expect(summary.weeks).toHaveLength(2);
    expect(summary.totals.created).toBe(1);
    expect(summary.totals.completed).toBe(0);
    expect(summary.currentStreakDays).toBe(0);
    expect(mocks.cacheSetJson).toHaveBeenCalled();
  });

  it("clamps weeks into the supported range", async () => {
    mocks.find.mockReturnValue(leanQuery([]));
    mocks.countDocuments.mockResolvedValue(0);

    const summary = await analyticsService.getWeeklySummary("user-1", 999);

    expect(analyticsService.getWeeklySummary).toBeDefined();
    expect(summary.weeks).toHaveLength(52);
  });

  it("computes completion rates, on-time/late, and streak branches", async () => {
    const now = new Date();
    const today = new Date(now);
    today.setHours(12, 0, 0, 0);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);
    const twoDaysAgo = new Date(today);
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);

    mocks.find.mockImplementation((filter: unknown) => {
      const f = filter as Record<string, unknown>;
      if (f.createdAt) return leanQuery([]); // created==0, completed>0 => rate 1
      if (f.completedAt && f.dueDate) {
        return leanQuery([
          {
            completedAt: yesterday,
            dueDate: new Date(yesterday.getTime() + DAY),
          }, // on time
          {
            completedAt: yesterday,
            dueDate: new Date(yesterday.getTime() - DAY),
          }, // late
        ]);
      }
      if (f.completedAt) {
        return leanQuery([
          { completedAt: today },
          { completedAt: yesterday },
          { completedAt: twoDaysAgo },
        ]);
      }
      return leanQuery([]);
    });
    mocks.countDocuments.mockResolvedValue(3);

    const summary = await analyticsService.getWeeklySummary("user-1", 4);

    expect(summary.totals.created).toBe(0);
    expect(summary.totals.completed).toBe(3);
    expect(summary.totals.completionRate).toBe(1);
    expect(summary.totals.completedOnTime).toBe(1);
    expect(summary.totals.completedLate).toBe(1);
    expect(summary.totals.overdueOpen).toBe(3);
    expect(summary.currentStreakDays).toBeGreaterThanOrEqual(2);
  });
});

describe("analyticsService.getPrioritySuggestions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("ranks overdue tasks as urgent and sorts by score", async () => {
    const now = Date.now();
    mocks.find.mockReturnValue(
      leanQuery([
        {
          _id: "task-future",
          title: "Future task",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 30 * DAY),
        },
        {
          _id: "task-overdue",
          title: "Overdue task",
          priority: "low",
          status: "todo",
          dueDate: new Date(now - 2 * DAY),
        },
      ]),
    );

    const result = await analyticsService.getPrioritySuggestions("user-1", 10);

    expect(result.suggestions[0].taskId).toBe("task-overdue");
    expect(result.suggestions[0].suggestedPriority).toBe("urgent");
    expect(result.suggestions[0].score).toBeGreaterThanOrEqual(85);
    expect(result.suggestions[1].suggestedPriority).toBe("low");
  });

  it("boosts in-progress tasks and flags missing due dates", async () => {
    mocks.find.mockReturnValue(
      leanQuery([
        {
          _id: "task-progress",
          title: "In progress",
          priority: "medium",
          status: "in_progress",
          dueDate: null,
        },
      ]),
    );

    const result = await analyticsService.getPrioritySuggestions("user-1", 10);

    expect(result.suggestions[0].reasons).toContain("No due date set");
    expect(result.suggestions[0].reasons).toContain("Already in progress");
  });

  it("clamps the suggestion limit", async () => {
    mocks.find.mockReturnValue(leanQuery([]));
    const result = await analyticsService.getPrioritySuggestions(
      "user-1",
      9999,
    );
    expect(result.suggestions).toHaveLength(0);
  });

  it("classifies due-date proximity buckets", async () => {
    const now = Date.now();
    mocks.find.mockReturnValue(
      leanQuery([
        {
          _id: "t0",
          title: "Today",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 2 * 60 * 60 * 1000),
        },
        {
          _id: "t2",
          title: "Soon",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 2 * DAY),
        },
        {
          _id: "t7",
          title: "Week",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 6 * DAY),
        },
        {
          _id: "t14",
          title: "Two weeks",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 10 * DAY),
        },
        {
          _id: "t30",
          title: "Later",
          priority: "low",
          status: "todo",
          dueDate: new Date(now + 30 * DAY),
        },
      ]),
    );

    const result = await analyticsService.getPrioritySuggestions("user-1", 20);
    const byId = Object.fromEntries(
      result.suggestions.map((s) => [s.taskId, s]),
    );

    expect(byId.t0.suggestedPriority).toBe("urgent");
    expect(byId.t2.suggestedPriority).toBe("high");
    expect(byId.t7.suggestedPriority).toBe("medium");
    expect(byId.t14.suggestedPriority).toBe("medium");
    expect(byId.t30.suggestedPriority).toBe("low");
  });
});

describe("analyticsService.applyPrioritySuggestions", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("updates only tasks whose suggested priority differs", async () => {
    const now = Date.now();
    mocks.find.mockReturnValue(
      leanQuery([
        {
          _id: "task-overdue",
          title: "Overdue",
          priority: "low",
          status: "todo",
          dueDate: new Date(now - DAY),
        },
        {
          _id: "task-already",
          title: "Already urgent",
          priority: "urgent",
          status: "todo",
          dueDate: new Date(now - DAY),
        },
      ]),
    );
    mocks.updateOne.mockResolvedValue({ modifiedCount: 1 });

    const result = await analyticsService.applyPrioritySuggestions("user-1");

    expect(result.updated).toBe(1);
    expect(mocks.updateOne).toHaveBeenCalledTimes(1);
    expect(mocks.updateOne.mock.calls[0][0]).toMatchObject({
      _id: "task-overdue",
      userId: "user-1",
    });
  });

  it("returns zero when no priority changes are needed", async () => {
    const now = Date.now();
    mocks.find.mockReturnValue(
      leanQuery([
        {
          _id: "task-already",
          title: "Already urgent",
          priority: "urgent",
          status: "todo",
          dueDate: new Date(now - DAY),
        },
      ]),
    );

    await expect(
      analyticsService.applyPrioritySuggestions("user-1"),
    ).resolves.toEqual({ updated: 0 });
    expect(mocks.updateOne).not.toHaveBeenCalled();
  });
});
