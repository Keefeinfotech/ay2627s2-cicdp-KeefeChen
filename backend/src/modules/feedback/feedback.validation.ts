import { z } from "zod";

export const createFeedbackSchema = z.object({
  title: z
    .string({ message: "Title is required" })
    .trim()
    .min(1, "Title cannot be empty")
    .max(150, "Title must not exceed 150 characters"),
  description: z
    .string({ message: "Description is required" })
    .trim()
    .min(1, "Description cannot be empty"),
  category: z
    .enum(["BUG", "FEATURE_REQUEST", "GENERAL", "UI_UX"])
    .optional(),
  rating: z
    .number()
    .int("Rating must be a whole number")
    .min(1, "Rating must be between 1 and 5")
    .max(5, "Rating must be between 1 and 5")
    .optional(),
});

export const updateFeedbackStatusSchema = z.object({
  status: z.enum(["PENDING", "IN_REVIEW", "RESOLVED", "DISMISSED"], {
    message: "Status is required and must be a valid option",
  }),
});

export type CreateFeedbackInput = z.infer<typeof createFeedbackSchema>;
export type UpdateFeedbackStatusInput = z.infer<typeof updateFeedbackStatusSchema>;