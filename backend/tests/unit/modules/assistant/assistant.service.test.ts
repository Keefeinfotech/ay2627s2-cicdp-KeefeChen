import { beforeEach, describe, expect, it, vi } from "vitest";

const mocks = vi.hoisted(() => {
  const save = vi.fn().mockResolvedValue(undefined);
  const findOne = vi.fn();
  const create = vi.fn();
  const AssistantDraft = vi.fn().mockImplementation(function (
    this: Record<string, unknown>,
    input: Record<string, unknown>,
  ) {
    Object.assign(this, input, { save });
  });
  Object.assign(AssistantDraft, { findOne, create });

  return {
    save,
    findOne,
    create,
    AssistantDraft,
    createTaskDraft: vi.fn(),
    createTask: vi.fn(),
    listTasks: vi.fn(),
  };
});

vi.mock("../../../../src/modules/assistant/assistant-draft.model.js", () => ({
  AssistantDraft: mocks.AssistantDraft,
}));
vi.mock("../../../../src/modules/ai/ai.service.js", () => ({
  createTaskDraft: mocks.createTaskDraft,
}));
vi.mock("../../../../src/modules/tasks/task.service.js", () => ({
  taskService: { createTask: mocks.createTask, listTasks: mocks.listTasks },
}));

import { assistantService } from "../../../../src/modules/assistant/assistant.service.js";

const draft = (overrides: Record<string, unknown> = {}) => ({
  _id: "draft-1",
  userId: "user-1",
  message: "Plan my week",
  context: [],
  currentDate: "2026-11-21",
  utcOffsetMinutes: 0,
  draft: {
    title: "Study biology",
    description: "Chapter 4",
    course: "BIO",
    priority: "high",
    tags: ["exam"],
    dueDate: "2026-11-25",
  },
  clarification: null,
  reply: "Here is a draft.",
  status: "pending",
  taskId: null,
  save: mocks.save,
  ...overrides,
});

const draftResult = () => ({
  draft: { title: "Study biology", priority: "high", tags: ["exam"] },
  clarification: null,
  reply: "Here is a draft.",
});

describe("assistantService", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.createTaskDraft.mockResolvedValue(draftResult());
    mocks.findOne.mockReturnValue({ lean: vi.fn().mockResolvedValue(null) });
    mocks.create.mockImplementation((input: Record<string, unknown>) =>
      draft(input),
    );
  });

  it("interprets a message into an expiring pending draft", async () => {
    const result = await assistantService.interpret("user-1", {
      message: "Plan my week",
    });

    expect(mocks.createTaskDraft).toHaveBeenCalledOnce();
    expect(mocks.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: "user-1", status: "pending" }),
    );
    expect(result).toMatchObject({
      status: "pending",
      reply: "Here is a draft.",
    });
  });

  it("clarifies using the previous conversation", async () => {
    mocks.findOne.mockResolvedValue(draft());
    const result = await assistantService.clarify("user-1", {
      draftId: "draft-1",
      message: "Make it tomorrow",
    });

    expect(mocks.createTaskDraft).toHaveBeenCalledTimes(1);
    expect(mocks.save).toHaveBeenCalled();
    expect(result.status).toBe("pending");
  });

  it("applies only allow-listed edits in a preview", async () => {
    mocks.findOne.mockResolvedValue(draft());
    const result = await assistantService.preview("user-1", {
      draftId: "draft-1",
      edits: { title: "Edited title", malicious: "ignored" } as never,
    });

    expect(result.preview).toMatchObject({ title: "Edited title" });
    expect(result.preview).not.toHaveProperty("malicious");
  });

  it("previews a draft without edits", async () => {
    mocks.findOne.mockResolvedValue(draft());
    const result = await assistantService.preview("user-1", {
      draftId: "d-1",
    });
    expect(result.preview).toMatchObject({ title: "Study biology" });
  });

  it("creates a task from a confirmed draft", async () => {
    mocks.findOne.mockResolvedValue(draft());
    mocks.createTask.mockResolvedValue({ _id: "task-1" });

    const result = await assistantService.confirm("user-1", {
      draftId: "draft-1",
      edits: { title: "Confirmed title" },
    });

    expect(mocks.createTask).toHaveBeenCalledWith(
      "user-1",
      expect.objectContaining({ title: "Confirmed title", priority: "high" }),
    );
    expect(mocks.save).toHaveBeenCalled();
    expect(result.draftId).toBe("draft-1");
  });

  it("rejects confirmation without a title", async () => {
    mocks.findOne.mockResolvedValue(draft({ draft: { title: "" } }));
    await expect(
      assistantService.confirm("user-1", { draftId: "draft-1" }),
    ).rejects.toMatchObject({ status: 422, code: "DRAFT_MISSING_TITLE" });
    expect(mocks.createTask).not.toHaveBeenCalled();
  });

  it("cancels a pending draft using literal query values", async () => {
    mocks.findOne.mockResolvedValue(draft());
    const result = await assistantService.cancel("user-1", {
      draftId: "draft-1",
    });

    expect(mocks.findOne).toHaveBeenCalledWith(
      expect.objectContaining({
        _id: { $eq: "draft-1" },
        userId: { $eq: "user-1" },
      }),
    );
    expect(result).toMatchObject({ status: "cancelled" });
  });

  it("rejects a missing draft", async () => {
    mocks.findOne.mockResolvedValue(null);
    await expect(
      assistantService.cancel("user-1", { draftId: "draft-1" }),
    ).rejects.toMatchObject({ status: 404, code: "DRAFT_NOT_FOUND" });
  });

  it("produces suggestions from open tasks", async () => {
    mocks.listTasks.mockResolvedValue({
      items: [
        {
          title: "Overdue essay",
          dueDate: new Date(Date.now() - 86400000),
        },
        {
          title: "Due soon quiz",
          dueDate: new Date(Date.now() + 3600000),
        },
      ],
    });

    const result = await assistantService.suggestions("user-1");
    expect(result.suggestions.length).toBeGreaterThan(0);
    expect(result.suggestions[0]).toContain("Overdue essay");
    expect(result.suggestions.join(" ")).toContain("Due soon quiz");
  });
});
