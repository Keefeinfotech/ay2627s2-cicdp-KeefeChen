/**
 * File Name: index.ts
 * Description: Module entry point and dependency injection wiring for the sync module.
 * Author: Keefe Chen
 */

import { Router } from "express";

import { SyncRepository } from "./sync.repository";
import { SyncService } from "./sync.service";
import { SyncController } from "./sync.controller";
import { createSyncRouter } from "./sync.routes";

const syncRepository = new SyncRepository();
const syncService = new SyncService(syncRepository);
const syncController = new SyncController(syncService);

const router = Router();

// Sync change-feed route
router.use("/changes", createSyncRouter(syncController));

// Export the combined router as default
export default router;

// Re-export types and services for DI
export { SyncService } from "./sync.service.js";
export type { TaskChange, SyncChangesResult } from "./sync.types.js";