import type { NextFunction, Request, Response } from "express";
import { createChatReply } from "./ai.service.js";

export const chat = async (
  req: Request,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const { message } = req.body as { message: string };
    res.status(200).json(await createChatReply(message));
  } catch (err) {
    next(err);
  }
};
