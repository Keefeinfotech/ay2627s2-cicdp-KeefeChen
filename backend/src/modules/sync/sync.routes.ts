/**
 * File Name: sync.routes.ts
 * Description: Route bindings and HTTP endpoint definitions for sync module.
 * Author: Keefe Chen
 */

import { Router } from 'express';
import { SyncController } from './sync.controller';

export function createSyncRouter(syncController: SyncController): Router {
  const router = Router();

  // GET /api/v1/sync/changes?since=2026-01-01T00:00:00.000Z
  router.get('/changes', syncController.getChanges);

  // POST /api/v1/sync/push
  router.post('/push', syncController.pushChanges);

  return router;
}