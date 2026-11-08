import { z } from "zod";

const email = z
  .string()
  .trim()
  .toLowerCase()
  .min(3)
  .max(254)
  .email("Enter a valid email address");

// Common passwords that should be rejected even if they meet complexity rules.
const COMMON_PASSWORDS = new Set([
  "password",
  "password1",
  "password123",
  "password123!",
  "Password123!",
  "123456",
  "12345678",
  "123456789",
  "qwerty",
  "abc123",
  "admin",
  "letmein",
  "welcome",
  "welcome123!",
  "monkey",
  "dragon",
  "master",
  "login",
  "pass",
  "test",
  "guest",
]);

const MIN_PASSWORD_LENGTH = 12;

const password = z
  .string()
  .min(
    MIN_PASSWORD_LENGTH,
    `Password must be at least ${MIN_PASSWORD_LENGTH} characters`,
  )
  .max(128, "Password must be at most 128 characters")
  .refine((val) => {
    if (!/[A-Z]/.test(val))
      return "Password must contain at least one uppercase letter";
    if (!/[a-z]/.test(val))
      return "Password must contain at least one lowercase letter";
    if (!/\d/.test(val)) return "Password must contain at least one number";
    if (!/[^A-Za-z\d]/.test(val))
      return "Password must contain at least one special character";
    if (COMMON_PASSWORDS.has(val.toLowerCase()))
      return "Password is too common — please choose a harder-to-guess password";
    return true;
  });

const name = z.string().trim().max(80, "Name must be at most 80 characters");

const captchaToken = z.string().max(4096).optional();

export const signupSchema = z.object({
  body: z
    .object({
      name: name.optional(),
      email,
      password,
      captchaToken,
    })
    .strict(),
});

export const loginSchema = z.object({
  body: z
    .object({
      email,
      password: z.string().min(1, "Password is required").max(128),
      captchaToken,
    })
    .strict(),
});
