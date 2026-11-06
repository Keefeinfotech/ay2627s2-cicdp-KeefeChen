/**
 * File Name: member.validation.ts
 * Description: Request validation schemas for member endpoints.
 * Author: Keefe Chen
 */

import { z } from "zod";
import { GroupRole } from "../core/group.types.js";

export const addMemberSchema = z.object({
  userId: z.string().min(1, { message: "User ID is required." }),
  role: z.nativeEnum(GroupRole).optional(),
});

export const updateMemberRoleSchema = z.object({
  role: z.nativeEnum(GroupRole, {
    message: "Role is required.",
  }),
});