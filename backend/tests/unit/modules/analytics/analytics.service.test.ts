import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const find = vi.fn();
  const countDocuments = vi.fn();
  const updateOne = vi.fn();

  return {
    find,
    countDocuments,
    updateOne,
    Task: { find, countDocuments, updateOne },
  };
});

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: mocks.Task,
}));

import { analyticsService } from "../../../../src/modules/analytics/analytics.service.js";

function leanQuery(result: unknown) {
  return {
    select: vi.fn().mockReturnThis(),
    lean: vi.fn().mockResolvedValue(result),
  };
}

const DAY = 24 * 60 * 60 * 1000;

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
    const result = await analyticsService.getPrioritySuggestions("user-1", 9999);
    expect(result.suggestions).toHaveLength(0);
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
});
