import { body, query, param } from "express-validator";
import { EventPriority, EventStatus } from "./calendar.model";

export const createEventValidation = [
  body("title").isString().notEmpty().withMessage("Title is required"),
  body("startTime")
    .isISO8601()
    .toDate()
    .withMessage("Valid start time is required"),
  body("endTime")
    .isISO8601()
    .toDate()
    .withMessage("Valid end time is required")
    .custom((endTime, { req }) => {
      if (new Date(endTime) <= new Date(req.body.startTime)) {
        throw new Error("End time must be after start time");
      }
      return true;
    }),
  body("priority")
    .optional()
    .isIn(Object.values(EventPriority))
    .withMessage("Invalid priority level"),
  body("groupId").optional().isUUID().withMessage("Invalid group ID"),
  body("taskId").optional().isUUID().withMessage("Invalid task ID"),
];

export const updateEventValidation = [
  param("id").isMongoId().withMessage("Invalid event ID"),
  body("title").optional().isString().notEmpty(),
  body("startTime").optional().isISO8601().toDate(),
  body("endTime")
    .optional()
    .isISO8601()
    .toDate()
    .custom((endTime, { req }) => {
      if (
        req.body.startTime &&
        new Date(endTime) <= new Date(req.body.startTime)
      ) {
        throw new Error("End time must be after start time");
      }
      return true;
    }),
  body("status")
    .optional()
    .isIn(Object.values(EventStatus))
    .withMessage("Invalid status value"),
];

export const getEventsQueryValidation = [
  query("startDate")
    .isISO8601()
    .toDate()
    .withMessage("Valid startDate query param required"),
  query("endDate")
    .isISO8601()
    .toDate()
    .withMessage("Valid endDate query param required"),
  query("groupId").optional().isUUID(),
];
