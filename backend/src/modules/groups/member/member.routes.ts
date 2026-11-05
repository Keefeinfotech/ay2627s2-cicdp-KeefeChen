import { Router } from "express";
import { MemberController } from "./member.controller";
import {
  addMemberSchema,
  updateMemberRoleSchema,
} from "./member.validation.js";
import { validateBody } from "../../../middleware/validateRequest.js";
import { authenticate } from "../../../middleware/authenticate.js";

export function createMemberRouter(
  memberController: MemberController
): Router {
  const router = Router({ mergeParams: true });

  // All member routes require authentication
  router.use(authenticate);

  // List members of a group
  router.get("/", memberController.list);

  // Add a member to a group
  router.post("/", validateBody(addMemberSchema), memberController.add);

  // Update member role
  router.patch(
    "/:userId/role",
    validateBody(updateMemberRoleSchema),
    memberController.updateRole
  );

  // Remove member from group
  router.delete("/:userId", memberController.remove);

  return router;
}