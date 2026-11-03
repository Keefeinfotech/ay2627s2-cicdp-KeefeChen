/**
 * File Name: batch.controller.ts
 * Description: Handles HTTP requests for bulk membership operations.
 * Author: Keefe Chen
 */

import type {
  NextFunction,
  Request,
  Response,
} from "express";

import { batchService } from "./batch.service.js";

export const batchController = {
  /**
   * POST /api/groups/:groupId/members/batch
   * Adds several members to a group in one request.
   */
  async addMembers(
    req: Request,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const requesterId = req.userId;
      const groupId = req.params.groupId;

      if (!requesterId) {
        res.status(401).json({
          code: "UNAUTHENTICATED",
          message: "Authentication is required.",
        });
        return;
      }

      if (typeof groupId !== "string" || !groupId) {
        res.status(400).json({
          code: "INVALID_GROUP_ID",
          message: "A group ID is required.",
        });
        return;
      }

      const outcome = await batchService.addMembers(
        groupId,
        requesterId,
        req.body,
      );

      if (outcome.mode === "partial" && outcome.result.failed.length > 0) {
        // HTTP 207 Multi-Status: part of the batch was rejected.
        res.status(207).json({
          message: "Batch completed with partial failures.",
          data: outcome.result,
          job: outcome.job,
        });
        return;
      }

      res.status(200).json({
        message: "Batch operation completed successfully.",
        data: outcome.result,
        job: outcome.job,
      });
    } catch (error) {
      next(error);
    }
  },
};
