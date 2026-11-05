/**
 * File Name: group.controller.ts
 * Description: Controller layer handling HTTP requests for group endpoints.
 * Author: Keefe Chen
 */

import { Response, NextFunction } from "express";
import { GroupService } from "./group.services";
import { AuthenticatedRequest, GroupListQuery } from "./group.types.js";

export class GroupController {
  constructor(private readonly groupService: GroupService) {}

  public create = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const group = await this.groupService.create(userId, req.body);
      res.status(201).json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  public list = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const query: GroupListQuery = {
        page: req.query.page ? parseInt(req.query.page as string, 10) : 1,
        limit: req.query.limit ? parseInt(req.query.limit as string, 10) : 10,
        search: req.query.search ? (req.query.search as string) : undefined,
      };

      const result = await this.groupService.list(userId, query);
      res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  };

  public get = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const group = await this.groupService.get(groupId, userId);
      res.status(200).json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  public update = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const group = await this.groupService.update(groupId, userId, req.body);
      res.status(200).json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };

  public archive = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const group = await this.groupService.archive(groupId, userId);
      res.status(200).json({ success: true, data: group });
    } catch (error) {
      next(error);
    }
  };
}