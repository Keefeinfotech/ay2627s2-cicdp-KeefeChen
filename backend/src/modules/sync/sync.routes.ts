/**
 * File Name: sync.routes.ts
 * Description: Defines authenticated sync endpoint definitions.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import type { SyncController } from "./sync.controller.js";
import { resolveConflictSchema, syncPushSchema } from "./sync.validation.js";

export function createSyncRouter(syncController: SyncController): Router {
  const router = Router();

  router.use(authenticate);

  // GET /api/sync/changes?since=2026-01-01T00:00:00.000Z
  router.get("/changes", syncController.getChanges);

  // GET /api/sync/pull?since|cursor=<ISO-8601> (alias of /changes)
  router.get("/pull", syncController.pull);

  // POST /api/sync/push { operations: [...] } - idempotent batch push
  router.post("/push", validateRequest(syncPushSchema), syncController.push);

  // POST /api/sync/batch - alias of /push
  router.post("/batch", validateRequest(syncPushSchema), syncController.push);

  // GET /api/sync/status - server sync status for diagnostics
  router.get("/status", syncController.status);

  // POST /api/sync/resolve-conflict
  router.post(
    "/resolve-conflict",
    validateRequest(resolveConflictSchema),
    syncController.resolveConflict,
  );

  return router;
}
