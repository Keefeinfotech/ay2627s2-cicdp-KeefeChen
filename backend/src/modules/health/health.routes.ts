import { Router } from "express";
import {
  healthCheck,
  livenessCheck,
  readinessCheck,
} from "./health.controller.js";

const router = Router();

router.get("/", healthCheck);
router.get("/live", livenessCheck);
router.get("/ready", readinessCheck);

export default router;
