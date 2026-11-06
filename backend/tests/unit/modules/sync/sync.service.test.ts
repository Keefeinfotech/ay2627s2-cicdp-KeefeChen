import { beforeEach, describe, expect, it, vi } from "vitest";

import type { ISyncRepository } from "../../../../src/modules/sync/sync.repository.js";
import { SyncService } from "../../../../src/modules/sync/sync.service.js";
import type { TaskChange } from "../../../../src/modules/sync/sync.types.js";

const task: TaskChange = {
  id: "task-1",
  userId: "user-1",
  title: "Revise calculus",
  description: "Chapters 3 and 4",
  course: "MATH 101",
  tags: ["Maths"],
  groupId: "group-1",
  assigneeId: "user-1",
  assigneeName: "Asha",
  reminderAt: null,
  status: "todo",
  priority: "high",
  dueDate: null,
  completedAt: null,
  deletedAt: null,
  createdAt: new Date("2026-11-01T09:00:00Z"),
  updatedAt: new Date("2026-11-05T09:00:00Z"),
};

describe("sync service", () => {
  const repository: ISyncRepository = {
    fetchChangesSince: vi.fn(),
  };
  const service = new SyncService(repository);

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns the repository changes with a server timestamp", async () => {
    vi.mocked(repository.fetchChangesSince).mockResolvedValue([task]);
    const since = new Date("2026-11-01T00:00:00Z");

    const result = await service.getChangesSince("user-1", since);

    expect(repository.fetchChangesSince).toHaveBeenCalledWith("user-1", since);
    expect(result.since).toBe(since);
    expect(result.serverTime).toBeInstanceOf(Date);
    expect(result.tasks).toEqual([task]);
  });
});
