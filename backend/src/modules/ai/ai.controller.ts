import type { NextFunction, Request, Response } from "express";
import { createChatReply, createTaskDraft, type ConversationTurn } from "./ai.service.js";
import { taskDraftResponseSchema } from "./ai.validation.js";

export const chat = async (
  req: Request,
  res: Response,
  next: NextFunction
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
  next: NextFunction
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
