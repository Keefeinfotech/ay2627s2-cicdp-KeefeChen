import { z } from "zod";
import { GroupVisibility } from "./group.types";

export const createGroupSchema = z.object({
  name: z.string()
    .trim()
    .min(2, "Group name must contain at least 2 characters.")
    .max(80, "Group name cannot exceed 80 characters."),

  description: z.string()
    .trim()
    .max(500, "Description cannot exceed 500 characters.")
    .optional(),

  visibility: z.nativeEnum(GroupVisibility)
    .default(GroupVisibility.PRIVATE),
});

export const updateGroupSchema = z.object({
  name: z.string().trim().min(2).max(80).optional(),
  description: z.string().trim().max(500).optional(),
  visibility: z.nativeEnum(GroupVisibility).optional(),
}).refine(
  (data) => Object.keys(data).length > 0,
  { message: "At least one field must be provided." }
);

export const groupParamsSchema = z.object({
  groupId: z.string().uuid(),
});

export const groupListQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  search: z.string().trim().max(80).optional(),
});