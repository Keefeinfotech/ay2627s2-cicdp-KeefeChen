/**
 * File Name: admin.validation.ts
 * Description: Request validation for the administrative module. All query
 *              parameters are coerced and range-checked before reaching the
 *              repository so the service layer can trust its inputs.
 * Author: Keefe Chen
 */

import { z } from "zod";

export const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z
    .string()
    .trim()
    .max(120)
    .optional()
    .transform((value) => (value && value.length > 0 ? value : undefined)),
  status: z.enum(["active", "disabled", "pending"]).optional(),
});

export const updateUserStatusBodySchema = z.object({
  status: z.enum(["active", "disabled"]),
});

export type ListUsersQueryInput = z.infer<typeof listUsersQuerySchema>;
export type UpdateUserStatusBodyInput = z.infer<
  typeof updateUserStatusBodySchema
>;
