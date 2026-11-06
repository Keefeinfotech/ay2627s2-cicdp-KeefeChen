import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.model.js", () => ({
  Task: {
    find: vi.fn(),
  },
}));

import { Task } from "../../../../src/modules/tasks/task.model.js";
import { SyncRepository } from "../../../../src/modules/sync/sync.repository.js";

const document = {
  _id: "task-1",
  userId: "owner-1",
  title: "Revise calculus",
  description: "Chapters 3 and 4",
  course: "MATH 101",
  tags: ["Maths"],
  groupId: "group-1",
  assigneeId: "user-2",
  assigneeName: "Asha",
  reminderAt: new Date("2026-11-10T09:00:00Z"),
  status: "todo",
  priority: "high",
  dueDate: new Date("2026-11-12T17:00:00Z"),
  completedAt: null,
  deletedAt: null,
  createdAt: new Date("2026-11-01T09:00:00Z"),
  updatedAt: new Date("2026-11-05T09:00:00Z"),
};

const mockFind = (rows: unknown[]) => {
  const exec = vi.fn().mockResolvedValue(rows);
  const lean = vi.fn().mockReturnValue({ exec });
  const select = vi.fn().mockReturnValue({ lean });
  vi.mocked(Task.find).mockReturnValue({ select } as any);
  return { exec, lean, select };
};

describe("sync repository", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it("returns personal and assigned tasks updated since the cursor", async () => {
    mockFind([document]);
    const since = new Date("2026-11-01T00:00:00Z");

    const result = await new SyncRepository().fetchChangesSince("user-2", since);

    expect(Task.find).toHaveBeenCalledWith({
      $or: [{ userId: "user-2" }, { assigneeId: "user-2" }],
      updatedAt: { $gt: since },
    });
    expect(result).toHaveLength(1);
    expect(result[0]).toMatchObject({
      id: "task-1",
      tags: ["Maths"],
      groupId: "group-1",
      assigneeId: "user-2",
      assigneeName: "Asha",
      deletedAt: null,
    });
  });
});
