/**
 * File Name: index.ts
 * Description: Module entry point and dependency injection wiring for sync.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { SyncController } from "./sync.controller.js";
import { SyncRepository } from "./sync.repository.js";
import { createSyncRouter } from "./sync.routes.js";
import { SyncService } from "./sync.service.js";

const syncRepository = new SyncRepository();
const syncService = new SyncService(syncRepository);
const syncController = new SyncController(syncService);

const router = Router();

router.use("/", createSyncRouter(syncController));

export default router;

export { SyncController, SyncRepository, SyncService };
export type { SyncChangesResult, TaskChange } from "./sync.types.js";
