/**
 * File Name: sync.routes.ts
 * Description: Authenticated HTTP endpoint definitions for sync.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import type { SyncController } from "./sync.controller.js";

export function createSyncRouter(syncController: SyncController): Router {
  const router = Router();

  router.use(authenticate);

  // GET /api/sync/changes?since=2026-01-01T00:00:00.000Z
  router.get("/changes", syncController.getChanges);

  return router;
}
