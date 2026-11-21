/**
 * File Name: preference.validation.ts
 * Description: Zod schemas for preferences endpoints.
 */

import { z } from "zod";

import { THEMES } from "./preference.model.js";

const isValidTimeZone = (tz: string): boolean => {
  try {
    new Intl.DateTimeFormat("en", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
};

export const updatePreferencesSchema = z.object({
  body: z
    .object({
      notifications: z
        .object({
          enabled: z.boolean().optional(),
          email: z.boolean().optional(),
          push: z.boolean().optional(),
          inApp: z.boolean().optional(),
          reminderMinutesBefore: z.number().int().min(0).max(1440).optional(),
        })
        .strict()
        .optional(),
      appearance: z
        .object({
          theme: z.enum(THEMES).optional(),
          fontScale: z.number().min(0.8).max(2).optional(),
        })
        .strict()
        .optional(),
      timezone: z
        .string()
        .trim()
        .max(64)
        .refine(isValidTimeZone, "Invalid time zone.")
        .optional(),
      locale: z.string().trim().min(2).max(16).optional(),
    })
    .strict()
    .refine((b) => Object.keys(b).length > 0, {
      message: "At least one preference section must be provided.",
    }),
});

export const updateNotificationPreferencesSchema = z.object({
  body: z
    .object({
      enabled: z.boolean().optional(),
      email: z.boolean().optional(),
      push: z.boolean().optional(),
      inApp: z.boolean().optional(),
      reminderMinutesBefore: z.number().int().min(0).max(1440).optional(),
    })
    .strict()
    .refine((b) => Object.keys(b).length > 0, {
      message: "At least one notification preference must be provided.",
    }),
});

export const updateAppearancePreferencesSchema = z.object({
  body: z
    .object({
      theme: z.enum(THEMES).optional(),
      fontScale: z.number().min(0.8).max(2).optional(),
    })
    .strict()
    .refine((b) => Object.keys(b).length > 0, {
      message: "At least one appearance preference must be provided.",
    }),
});

export const updateTimezoneSchema = z.object({
  body: z
    .object({
      timezone: z
        .string()
        .trim()
        .max(64)
        .refine(isValidTimeZone, "Invalid time zone."),
    })
    .strict(),
});
