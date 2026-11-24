import type { NextFunction, Request, Response } from "express";

import { AppError } from "../../shared/utils/AppError.js";
import type { SyncService } from "./sync.service.js";

const getAuthenticatedUserId = (req: Request): string => {
  const userId = req.userId;

  if (!userId) {
    throw new AppError(401, "UNAUTHENTICATED", "Authentication required.");
  }

  return userId;
};

const parseSince = (value: unknown): Date => {
  if (value === undefined) {
    return new Date(0);
  }

  if (typeof value !== "string") {
    throw new AppError(400, "INVALID_SINCE", "The sync cursor must be a date.");
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) {
    throw new AppError(
      400,
      "INVALID_SINCE",
      "The sync cursor must be a valid ISO-8601 date.",
    );
  }

  return parsed;
};

export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  public getChanges = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = getAuthenticatedUserId(req);
      const since = parseSince(req.query.since ?? req.query.cursor);
      const result = await this.syncService.getChangesSince(userId, since);

      res.status(200).json({
        message: "Sync changes retrieved successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };

  public pull = this.getChanges;

  public push = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = getAuthenticatedUserId(req);
      const { operations } = req.body as {
        operations: import("./sync.types.js").SyncOperationInput[];
      };
      const result = await this.syncService.push(userId, operations);

      res.status(200).json({
        message: "Sync operations processed.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };

  public status = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = getAuthenticatedUserId(req);
      const result = await this.syncService.getStatus(userId);

      res.status(200).json({
        message: "Sync status retrieved successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };

  public resolveConflict = async (
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = getAuthenticatedUserId(req);
      const { taskId, resolution, clientState } = req.body as Parameters<
        SyncService["resolveConflict"]
      >[1];

      const task = await this.syncService.resolveConflict(userId, {
        taskId,
        resolution,
        clientState,
      });

      res.status(200).json({
        message: "Conflict resolved successfully.",
        data: task,
      });
    } catch (error) {
      next(error);
    }
  };
}
