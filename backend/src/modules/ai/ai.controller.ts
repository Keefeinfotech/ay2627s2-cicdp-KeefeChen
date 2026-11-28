import type { NextFunction, Request, Response } from "express";
import {
  createChatReply,
  createTaskDraft,
  type ConversationTurn,
} from "./ai.service.js";
import { taskService } from "../tasks/task.service.js";
import { createTaskSchema } from "../tasks/task.validation.js";
import { taskDraftResponseSchema } from "./ai.validation.js";

export const chat = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { message, context } = req.body as {
      message: string;
      context?: ConversationTurn[];
    };
    res.status(200).json(await createChatReply(message, context));
  } catch (err) {
    next(err);
  }
};

export const taskDraft = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const { message, context, currentDate, utcOffsetMinutes } = req.body as {
      message: string;
      context?: ConversationTurn[];
      currentDate?: string;
      utcOffsetMinutes?: number;
    };
    const result = await createTaskDraft(message, context, {
      currentDate,
      utcOffsetMinutes,
    });
    // Validate provider output at the API boundary as well as in orchestration.
    res.status(200).json(taskDraftResponseSchema.parse(result));
  } catch (err) {
    next(err);
  }
};

export const createTaskAi = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ message: "Unauthenticated" });
      return;
    }
    // Validate through the same schema used by POST /api/tasks; never persist
    // unchecked AI/client-supplied fields, and reject invalid dates.
    const body = createTaskSchema.shape.body.parse(req.body);
    const task = await taskService.createTask(userId, body);
    res.status(201).json({ message: "Task created", task });
  } catch (err) {
    next(err);
  }
};

export const completeTaskAi = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ message: "Unauthenticated" });
      return;
    }
    const { taskId } = req.body as { taskId?: unknown };
    if (typeof taskId !== "string" || !taskId.trim()) {
      res.status(400).json({ message: "taskId is required" });
      return;
    }
    const task = await taskService.updateTask(userId, taskId, {
      status: "completed",
    } as never);
    res.status(200).json({ message: "Task completed", task });
  } catch (err) {
    next(err);
  }
};

export const deleteTaskAi = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ message: "Unauthenticated" });
      return;
    }
    const { taskId } = req.body as { taskId?: unknown };
    if (typeof taskId !== "string" || !taskId.trim()) {
      res.status(400).json({ message: "taskId is required" });
      return;
    }
    await taskService.deleteTask(userId, taskId);
    res.status(200).json({ message: "Task deleted" });
  } catch (err) {
    next(err);
  }
};

export const tasks = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ message: "Unauthenticated" });
      return;
    }
    const { status, priority, dueBefore, dueAfter } = req.query as Record<
      string,
      string | undefined
    >;
    const result = await taskService.listTasks(userId, {
      status: status ? (status.split(",") as never) : undefined,
      priority: priority ? (priority.split(",") as never) : undefined,
      dueBefore: dueBefore ? new Date(dueBefore) : undefined,
      dueAfter: dueAfter ? new Date(dueAfter) : undefined,
      limit: 100,
      sortBy: "dueDate",
      sortOrder: "asc",
    });
    res.status(200).json({
      count: result.items.length,
      tasks: result.items.map((task) => ({
        id: task._id,
        title: task.title,
        status: task.status,
        priority: task.priority,
        dueDate: task.dueDate,
      })),
    });
  } catch (err) {
    next(err);
  }
};

export const today = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = req.userId;
    if (!userId) {
      res.status(401).json({ message: "Unauthenticated" });
      return;
    }
    const tasks = await taskService.listTasks(userId, {
      status: ["todo", "in_progress"],
      limit: 50,
      sortBy: "dueDate",
      sortOrder: "asc",
    });
    const items = tasks.items.map((task) => ({
      id: task._id,
      title: task.title,
      dueDate: task.dueDate,
      priority: task.priority,
      status: task.status,
    }));
    const overdue = items.filter(
      (task) => task.dueDate && new Date(task.dueDate) < new Date(),
    );
    const summary =
      items.length === 0
        ? "You have no open tasks today. Great job!"
        : `You have ${items.length} open task(s). ` +
          (overdue.length > 0 ? `${overdue.length} are overdue. ` : "") +
          "Top priorities: " +
          items
            .slice(0, 3)
            .map((task) => task.title)
            .join(", ") +
          ".";
    res.status(200).json({ summary, tasks: items });
  } catch (err) {
    next(err);
  }
};
