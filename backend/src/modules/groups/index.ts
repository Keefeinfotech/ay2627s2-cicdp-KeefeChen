import { Router } from "express";

import groupRoutes from "./core/group.routes";
import batchRoutes from "./batch/batch.routes";

const router = Router();

// Group collection and detail routes.
router.use(groupRoutes);

// POST /api/groups/:groupId/members/batch
router.use("/:groupId/members/batch", batchRoutes);

export default router;
