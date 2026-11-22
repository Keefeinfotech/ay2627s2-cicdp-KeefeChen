/**
 * File Name: notification.routes.ts
 * Description: In-app notification and device registry routes.
 */

import { Router } from "express";

import { authenticate } from "../../middleware/authenticate.js";
import { validateRequest } from "../../middleware/validateRequest.js";

import { notificationController } from "./notification.controller.js";
import {
  deviceIdParamSchema,
  listNotificationsSchema,
  notificationIdParamSchema,
  registerDeviceSchema,
} from "./notification.validation.js";

const router = Router();

router.use(authenticate);

/** GET /api/notifications */
router.get(
  "/",
  validateRequest(listNotificationsSchema),
  notificationController.list,
);

/** GET /api/notifications/unread-count */
router.get("/unread-count", notificationController.unreadCount);

/** PATCH /api/notifications/read-all */
router.patch("/read-all", notificationController.markAllRead);

/** DELETE /api/notifications */
router.delete("/", notificationController.clearAll);

/** POST /api/notifications/devices */
router.post(
  "/devices",
  validateRequest(registerDeviceSchema),
  notificationController.registerDevice,
);

/** GET /api/notifications/devices */
router.get("/devices", notificationController.listDevices);

/** DELETE /api/notifications/devices/:deviceId */
router.delete(
  "/devices/:deviceId",
  validateRequest(deviceIdParamSchema),
  notificationController.unregisterDevice,
);

/** GET /api/notifications/:notificationId */
router.get(
  "/:notificationId",
  validateRequest(notificationIdParamSchema),
  notificationController.show,
);

/** PATCH /api/notifications/:notificationId/read */
router.patch(
  "/:notificationId/read",
  validateRequest(notificationIdParamSchema),
  notificationController.markRead,
);

/** DELETE /api/notifications/:notificationId */
router.delete(
  "/:notificationId",
  validateRequest(notificationIdParamSchema),
  notificationController.remove,
);

export default router;
