import {
  Router,
  type Request,
  type Response,
  type NextFunction,
} from "express";
import { validationResult } from "express-validator";
import { CalendarController } from "./calendar.controller";
import {
  createEventValidation,
  updateEventValidation,
  getEventsQueryValidation,
} from "./calendar.validation";

import { authenticate } from "../../middleware/authenticate";

const router = Router();
const controller = new CalendarController();

/**
 * Enforces the express-validator chains registered before it. Without this
 * the chains only collect errors and every invalid request falls through to
 * the repository, where it surfaces as a 500 instead of a 400.
 */
const enforceValidation = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    res.status(400).json({
      success: false,
      message: "Validation failed",
      errors: errors.array().map((element: { msg: string; path?: string }) => ({
        msg: element.msg,
        path: element.path ?? null,
      })),
    });
    return;
  }
  next();
};

router.use(authenticate);

router.post(
  "/",
  createEventValidation,
  enforceValidation,
  controller.createEvent,
);
router.get(
  "/",
  getEventsQueryValidation,
  enforceValidation,
  controller.getEvents,
);
router.get("/conflicts", controller.checkScheduleConflicts);
router.patch(
  "/:id",
  updateEventValidation,
  enforceValidation,
  controller.updateEvent,
);
router.delete("/:id", controller.deleteEvent);

export default router;
