import { describe, expect, it } from "vitest";
import { chatSchema } from "../../src/modules/ai/ai.validation";
import { loginSchema, signupSchema } from "../../src/modules/auth/auth.validation";

describe("signup validation", () => {
  it("normalises email casing and whitespace", () => {
    const parsed = signupSchema.parse({
      body: {
        name: "  Ada  ",
        email: "  ADA@Example.COM ",
        password: "password123",
      },
    });

    expect(parsed.body.email).toBe("ada@example.com");
    expect(parsed.body.name).toBe("Ada");
  });

  it("rejects an invalid email", () => {
    const result = signupSchema.safeParse({
      body: { email: "not-an-email", password: "password123" },
    });
    expect(result.success).toBe(false);
  });

  it("rejects a short password", () => {
    const result = signupSchema.safeParse({
      body: { email: "ada@example.com", password: "short" },
    });
    expect(result.success).toBe(false);
  });

  it("rejects oversized names", () => {
    const result = signupSchema.safeParse({
      body: {
        name: "x".repeat(81),
        email: "ada@example.com",
        password: "password123",
      },
    });
    expect(result.success).toBe(false);
  });
});

describe("login validation", () => {
  it("rejects a blank password", () => {
    const result = loginSchema.safeParse({
      body: { email: "ada@example.com", password: "" },
    });
    expect(result.success).toBe(false);
  });
});

describe("chat validation", () => {
  it("trims the message", () => {
    const parsed = chatSchema.parse({ body: { message: "  hello  " } });
    expect(parsed.body.message).toBe("hello");
  });

  it("rejects blank and oversized messages", () => {
    expect(chatSchema.safeParse({ body: { message: "   " } }).success).toBe(
      false
    );
    expect(
      chatSchema.safeParse({ body: { message: "x".repeat(1001) } }).success
    ).toBe(false);
  });
});
