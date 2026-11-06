import type {
  NextFunction,
  Request,
  Response,
} from "express";

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
      const since = parseSince(req.query.since);
      const result = await this.syncService.getChangesSince(userId, since);

      res.status(200).json({
        message: "Sync changes retrieved successfully.",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  };
}
