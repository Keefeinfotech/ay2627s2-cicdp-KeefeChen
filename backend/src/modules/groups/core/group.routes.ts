/**
 * File Name: group.routes.ts
 * Description: Route definitions and middleware bindings for group endpoints.
 * Author: Keefe Chen
 */

import { Router } from "express";
import { GroupController } from "./group.controller.js";
import {
  createGroupSchema,
  updateGroupSchema,
} from "./group.validation.js";
import { validateBody } from "../../../middleware/validateRequest.js";
import { authenticate } from "../../../middleware/authenticate.js";

export function createGroupRouter(groupController: GroupController): Router {
  const router = Router({ mergeParams: true });

  // All group routes require authentication.
  router.use(authenticate);

  // Create a group.
  router.post(
    "/",
    validateBody(createGroupSchema),
    groupController.create,
  );

  // List groups belonging to the current user.
  router.get(
    "/",
    groupController.list,
  );

  // Retrieve a group.
  router.get(
    "/:groupId",
    groupController.get,
  );

  // Update group details.
  router.patch(
    "/:groupId",
    validateBody(updateGroupSchema),
    groupController.update,
  );

  // Archive a group.
  router.delete(
    "/:groupId",
    groupController.archive,
  );

  return router;
}