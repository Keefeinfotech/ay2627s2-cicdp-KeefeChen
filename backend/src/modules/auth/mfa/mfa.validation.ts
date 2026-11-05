/**
 * File Name: mfa.validation.ts
 * Description: Zod schemas for MFA enrollment and management.
 * Author: Keefe Chen
 */

import { z } from "zod";

const codeSchema = z
  .string()
  .trim()
  .regex(/^\d{6}$/, "A 6-digit code is required.");

/**
 * POST /api/auth/mfa/verify
 */
export const verifyMfaSchema = z.object({
  body: z
    .object({
      code: codeSchema,
    })
    .strict(),
});

/**
 * POST /api/auth/mfa/disable
 */
export const disableMfaSchema = z.object({
  body: z
    .object({
      code: z
        .string()
        .trim()
        .min(6, "A verification code is required.")
        .max(20, "Verification code cannot exceed 20 characters."),
    })
    .strict(),
});
