import type { Request } from "express";
import { unauthorized } from "./AppError.js";

export const requireUserId = (req: Request): string => {
  if (!req.userId) {
    throw unauthorized();
  }
  return req.userId;
};

export const requireSessionId = (req: Request): string => {
  if (!req.sessionId) {
    throw unauthorized();
  }
  return req.sessionId;
};

export function getWelcomeMessage(name: string): string {
  return `Hello, ${name}! TypeScript NodeNext setup is working.`;
}
