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
  .min(MIN_PASSWORD_LENGTH, `Password must be at least ${MIN_PASSWORD_LENGTH} characters`)
  .max(128, "Password must be at most 128 characters")
  .refine(
    (val) => /[A-Z]/.test(val),
    "Password must contain at least one uppercase letter"
  )
  .refine(
    (val) => /[a-z]/.test(val),
    "Password must contain at least one lowercase letter"
  )
  .refine(
    (val) => /\d/.test(val),
    "Password must contain at least one number"
  )
  .refine(
    (val) => /[^A-Za-z\d]/.test(val),
    "Password must contain at least one special character"
  )
  .refine(
    (val) => !COMMON_PASSWORDS.has(val.toLowerCase()),
    "Password is too common — please choose a harder-to-guess password"
  );

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
