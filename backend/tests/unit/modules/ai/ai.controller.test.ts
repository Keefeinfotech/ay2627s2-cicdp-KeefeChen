import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../src/modules/tasks/task.service.js", () => ({
  taskService: {
    createTask: vi.fn(),
    getTask: vi.fn(),
    listTasks: vi.fn(),
    updateTask: vi.fn(),
    deleteTask: vi.fn(),
  },
}));

vi.mock("../../../../src/modules/ai/ai.service.js", () => ({
  createChatReply: vi.fn(),
  createTaskDraft: vi.fn(),
}));

import * as aiController from "../../../../src/modules/ai/ai.controller.js";
import {
  createChatReply,
  createTaskDraft,
} from "../../../../src/modules/ai/ai.service.js";
import { taskService } from "../../../../src/modules/tasks/task.service.js";


const ok = () => ({
  status: vi.fn().mockReturnThis(),
  json: vi.fn().mockReturnThis(),
});

describe("ai controller", () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe("chat", () => {
    it("returns the chat reply", async () => {
      vi.mocked(createChatReply).mockResolvedValue({ reply: "hi" });

      const res = ok();
      await aiController.chat(
        { body: { message: "hello", context: [] } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(createChatReply).toHaveBeenCalledWith("hello", []);
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({ reply: "hi" });
    });

    it("passes conversation context through", async () => {
      vi.mocked(createChatReply).mockResolvedValue({ reply: "ok" });
      const res = ok();

      await aiController.chat(
        {
          body: {
            message: "hello",
            context: [{ role: "user", content: "hi" }],
          },
        } as never,
        res as never,
        vi.fn() as never,
      );

      expect(createChatReply).toHaveBeenCalledWith("hello", [
        { role: "user", content: "hi" },
      ]);
    });

    it("forwards errors to the error handler", async () => {
      vi.mocked(createChatReply).mockRejectedValue(new Error("boom"));
      const next = vi.fn();

      await aiController.chat(
        { body: { message: "hello" } } as never,
        ok() as never,
        next as never,
      );

      expect(next).toHaveBeenCalled();
    });
  });

  describe("taskDraft", () => {
    it("validates and returns a task draft", async () => {
      vi.mocked(createTaskDraft).mockResolvedValue({ title: "New task" });
      const res = ok();

      await aiController.taskDraft(
        {
          body: {
            message: "remind me to write report",
            currentDate: "2026-11-24",
          },
        } as never,
        res as never,
        vi.fn() as never,
      );

      expect(createTaskDraft).toHaveBeenCalledWith(
        "remind me to write report",
        undefined,
        { currentDate: "2026-11-24", utcOffsetMinutes: undefined },
      );
      expect(res.status).toHaveBeenCalledWith(200);
    });

    it("maps invalid drafts to the error handler", async () => {
      vi.mocked(createTaskDraft).mockRejectedValue(new Error("invalid draft"));
      const next = vi.fn();

      await aiController.taskDraft(
        { body: { message: "x" } } as never,
        ok() as never,
        next as never,
      );

      expect(next).toHaveBeenCalled();
    });
  });

  describe("createTaskAi", () => {
    it("creates a task from an ai prompt", async () => {
      vi.mocked(taskService.createTask).mockResolvedValue({
        _id: "task-1",
      } as never);
      const res = ok();

      await aiController.createTaskAi(
        {
          user: { id: "user-1" },
          body: {
            title: "Write report",
            description: "d",
            dueDate: "2026-12-01",
            priority: "high",
          },
        } as never,
        res as never,
        vi.fn() as never,
      );

      expect(taskService.createTask).toHaveBeenCalledWith("user-1", {
        title: "Write report",
        description: "d",
        dueDate: new Date("2026-12-01"),
        priority: "high",
      });
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith({
        message: "Task created",
        task: { _id: "task-1" },
      });
    });

    it("requires a title", async () => {
      const res = ok();

      await aiController.createTaskAi(
        { user: { id: "user-1" }, body: { description: "d" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ message: "title is required" });
    });

    it("rejects unauthenticated requests", async () => {
      const res = ok();

      await aiController.createTaskAi(
        { body: { title: "T" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(401);
      expect(res.json).toHaveBeenCalledWith({ message: "Unauthenticated" });
    });
  });

  describe("completeTaskAi", () => {
    it("marks a task complete", async () => {
      vi.mocked(taskService.updateTask).mockResolvedValue({
        _id: "task-1",
      } as never);
      const res = ok();

      await aiController.completeTaskAi(
        { user: { id: "user-1" }, body: { taskId: "task-1" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(taskService.updateTask).toHaveBeenCalledWith("user-1", "task-1", {
        status: "completed",
      });
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        message: "Task completed",
        task: { _id: "task-1" },
      });
    });

    it("requires a taskId", async () => {
      const res = ok();

      await aiController.completeTaskAi(
        { user: { id: "user-1" }, body: { taskId: "" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(400);
      expect(res.json).toHaveBeenCalledWith({ message: "taskId is required" });
    });

    it("rejects unauthenticated requests", async () => {
      const res = ok();

      await aiController.completeTaskAi(
        { body: { taskId: "task-1" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(401);
    });
  });

  describe("deleteTaskAi", () => {
    it("deletes a task", async () => {
      vi.mocked(taskService.deleteTask).mockResolvedValue({
        _id: "task-1",
      } as never);
      const res = ok();

      await aiController.deleteTaskAi(
        { user: { id: "user-1" }, body: { taskId: "task-1" } } as never,
        res as never,
        vi.fn() as never,
      );

      expect(taskService.deleteTask).toHaveBeenCalledWith("user-1", "task-1");
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({ message: "Task deleted" });
    });

    it("requires a taskId", async () => {
      const res = ok();

      await aiController.deleteTaskAi(
        { user: { id: "user-1" }, body: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe("tasks", () => {
    it("returns a summarised task list", async () => {
      vi.mocked(taskService.listTasks).mockResolvedValue({
        items: [
          {
            _id: "task-1",
            title: "Write report",
            status: "todo",
            priority: "high",
            dueDate: "2026-12-01",
          },
        ],
      } as never);
      const res = ok();

      await aiController.tasks(
        { user: { id: "user-1" }, query: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(taskService.listTasks).toHaveBeenCalledWith(
        "user-1",
        expect.objectContaining({ limit: 100 }),
      );
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith({
        count: 1,
        tasks: [
          {
            id: "task-1",
            title: "Write report",
            status: "todo",
            priority: "high",
            dueDate: "2026-12-01",
          },
        ],
      });
    });

    it("returns 401 when unauthenticated", async () => {
      const res = ok();

      await aiController.tasks(
        { query: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(401);
    });
  });

  describe("today", () => {
    it("builds a summary from today's open tasks", async () => {
      vi.mocked(taskService.listTasks).mockResolvedValue({
        items: [
          {
            _id: "task-1",
            title: "Write report",
            status: "todo",
            priority: "high",
            dueDate: "2026-12-01",
          },
          {
            _id: "task-2",
            title: "Overdue",
            status: "todo",
            priority: "low",
            dueDate: "2020-01-01",
          },
        ],
      } as never);
      const res = ok();

      await aiController.today(
        { user: { id: "user-1" }, query: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          summary: expect.stringContaining(
            "You have 2 open task(s). 1 are overdue.",
          ),
        }),
      );
    });

    it("reports an empty day optimistically", async () => {
      vi.mocked(taskService.listTasks).mockResolvedValue({
        items: [],
      } as never);
      const res = ok();

      await aiController.today(
        { user: { id: "user-1" }, query: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.json).toHaveBeenCalledWith({
        summary: "You have no open tasks today. Great job!",
        tasks: [],
      });
    });

    it("requires authentication", async () => {
      const res = ok();

      await aiController.today(
        { query: {} } as never,
        res as never,
        vi.fn() as never,
      );

      expect(res.status).toHaveBeenCalledWith(401);
    });
  });
});
