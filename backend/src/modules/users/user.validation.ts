
/**
 * File Name: user.validation.ts
 * Description: Defines Zod validation schemas for user requests.
 * Author: Keefe Chen
 */

import { z } from "zod";

/**
 * Validates requests to update the authenticated user's profile.
 */
export const updateOwnProfileSchema = z.object({
  body: z
    .object({
      name: z
        .string()
        .trim()
        .min(2, "Name must contain at least 2 characters.")
        .max(80, "Name cannot exceed 80 characters.")
        .optional(),
    })
    .strict()
    .refine(
      (body) => Object.keys(body).length > 0,
      {
        message: "At least one profile field must be provided.",
      }
    ),
});

/**
 * Validates UUID route parameters.
 */
export const userIdParamSchema = z.object({
  params: z.object({
    userId: z.string().uuid("Invalid user ID format."),
  }),
});

/**
 * Validates requests to deactivate the authenticated user's account.
 *
 * Requires the current password as an additional security check.
 */
export const deleteOwnAccountSchema = z.object({
  body: z
    .object({
      currentPassword: z
        .string()
        .min(1, "Current password is required.")
        .max(128, "Password cannot exceed 128 characters."),
    })
    .strict(),
});

/**
 * Inferred request body types.
 */
export type UpdateOwnProfileBody = z.infer<
  typeof updateOwnProfileSchema
>["body"];

export type DeleteOwnAccountBody = z.infer<
  typeof deleteOwnAccountSchema
>["body"];
