import { Response, NextFunction } from "express";
import { MemberService } from "./member.services.js";
import { AuthenticatedRequest } from "./member.types.js";

export class MemberController {
  constructor(private readonly memberService: MemberService) {}

  public list = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const members = await this.memberService.listMembers(groupId, userId);
      res.status(200).json({ success: true, data: members });
    } catch (error) {
      next(error);
    }
  };

  public add = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const { userId: targetUserId, role } = req.body;

      const member = await this.memberService.addMember(
        groupId,
        userId,
        targetUserId,
        role
      );
      res.status(201).json({ success: true, data: member });
    } catch (error) {
      next(error);
    }
  };

  public updateRole = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const targetUserId = req.params.userId as string;
      const { role } = req.body;

      const updated = await this.memberService.updateMemberRole(
        groupId,
        userId,
        targetUserId,
        role
      );
      res.status(200).json({ success: true, data: updated });
    } catch (error) {
      next(error);
    }
  };

  public remove = async (
    req: AuthenticatedRequest,
    res: Response,
    next: NextFunction
  ): Promise<void> => {
    try {
      const userId = req.user?.id;
      if (!userId) {
        res.status(401).json({ success: false, error: "Unauthorized" });
        return;
      }

      const groupId = req.params.groupId as string;
      const targetUserId = req.params.userId as string;

      const removed = await this.memberService.removeMember(
        groupId,
        userId,
        targetUserId
      );
      res.status(200).json({ success: true, data: removed });
    } catch (error) {
      next(error);
    }
  };
}