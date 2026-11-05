/**
 * File Name: invitation.validation.ts
 * Description: Defines Zod validation schemas for group invitations.
 * Author: Keefe Chen
 */

import { z } from "zod";

import { GroupRole } from "../core/group.types.js";
import { InvitationStatus } from "./invitation.types.js";

/**
 * Validates invitation creation requests.
 *
 * Only ADMIN and MEMBER roles can be assigned through invitations.
 * OWNER privileges must not be granted through an invitation.
 */
export const createInvitationSchema = z.object({
  body: z.object({
    groupId: z
      .string()
      .trim()
      .uuid("Invalid group ID."),

    email: z
      .string()
      .trim()
      .email("Please provide a valid email address.")
      .max(254, "Email address is too long.")
      .transform((email) => email.toLowerCase()),

    role: z
      .enum([GroupRole.ADMIN, GroupRole.MEMBER])
      .default(GroupRole.MEMBER),
  }),
});

/**
 * Validates invitation acceptance requests.
 */
export const acceptInvitationSchema = z.object({
  body: z.object({
    token: z
      .string()
      .trim()
      .min(32, "Invalid invitation token.")
      .max(256, "Invalid invitation token."),
  }),
});

/**
 * Validates invitation route parameters.
 */
export const invitationParamsSchema = z.object({
  params: z.object({
    invitationId: z
      .string()
      .trim()
      .uuid("Invalid invitation ID."),
  }),
});

/**
 * Validates invitation listing query parameters.
 */
export const listInvitationsSchema = z.object({
  params: z.object({
    groupId: z
      .string()
      .trim()
      .uuid("Invalid group ID."),
  }),

  query: z.object({
    page: z.coerce
      .number()
      .int()
      .min(1)
      .default(1),

    limit: z.coerce
      .number()
      .int()
      .min(1)
      .max(100)
      .default(20),

    status: z
      .nativeEnum(InvitationStatus)
      .optional(),
  }),
});

/**
 * Validates invitation cancellation requests.
 */
export const cancelInvitationSchema = invitationParamsSchema;