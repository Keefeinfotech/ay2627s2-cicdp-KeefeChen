/**
 * File Name: index.ts
 * Description: Public exports for the Reminders module.
 * Author: Keefe Chen
 */

export { default as reminderRoutes } from "./reminder.routes.js";

export { reminderService } from "./reminder.service.js";

export type { Reminder } from "./reminder.model.js";
export type { ReminderCreateInput, ReminderProgressResponse } from "./reminder.types.js";