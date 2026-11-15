import type { NextFunction, Request, Response } from "express";
import {
  createChatReply,
  createTaskDraft,
  type ConversationTurn,
} from "./ai.service.js";
import { taskService } from "../tasks/task.service.js";
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

export const today = async (
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const userId = (req as Request & { user?: { id: string } }).user?.id;
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
          (overdue.length > 0
            ? `${overdue.length} are overdue. `
            : "") +
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
