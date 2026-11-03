import { Router } from "express";

import { GroupController } from "./group.controller";

import {
  createGroupSchema,
  updateGroupSchema,
} from "./group.validation.js";

import { validateBody } from "../../../middleware/validateRequest.js";
import { authenticate } from "../../../middleware/authenticate.js";

const router = Router();

// All group routes require authentication.
router.use(authenticate);

// Create a group.
router.post(
  "/",
  validateBody(createGroupSchema),
  GroupController.create,
);

// List groups belonging to the current user.
router.get(
  "/",
  GroupController.list,
);

// Retrieve a group.
router.get(
  "/:groupId",
  GroupController.get,
);

// Update group details.
router.patch(
  "/:groupId",
  validateBody(updateGroupSchema),
  GroupController.update,
);

// Archive a group.
router.delete(
  "/:groupId",
  GroupController.archive,
);

export default router;
