import { Router } from "express";

import { GroupRepository } from "./core/group.repository";
import { MemberRepository } from "./member/member.repository";
import { GroupService } from "./core/group.services";
import { GroupController } from "./core/group.controller";
import { createGroupRouter } from "./core/group.routes";
import batchRoutes from "./batch/batch.routes";
import memberRoutes from "./member/member.routes";

const groupRepository = new GroupRepository();
const memberRepository = new MemberRepository();
const groupService = new GroupService(groupRepository, memberRepository);
const groupController = new GroupController(groupService);

const router = Router();

// Group collection and detail routes.
router.use(createGroupRouter(groupController));

// POST /api/groups/:groupId/members/batch
router.use("/:groupId/members/batch", batchRoutes);

// GET /api/groups/:groupId/members
router.use("/:groupId/members", memberRoutes);

export default router;
