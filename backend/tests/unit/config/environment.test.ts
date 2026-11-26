import { afterEach, describe, expect, it, vi } from "vitest";

const ORIGINAL_ENV = { ...process.env };

const loadEnv = async () => {
  vi.resetModules();
  return import("../../../src/config/environment.js");
};

afterEach(() => {
  process.env = { ...ORIGINAL_ENV };
  vi.resetModules();
});

describe("environment config", () => {
  it("getRedisUrl trims and returns null when empty", async () => {
    process.env.REDIS_URL = " redis://localhost:6379 ";
    const env = await loadEnv();
    expect(env.getRedisUrl()).toBe("redis://localhost:6379");
    process.env.REDIS_URL = "  ";
    const env2 = await loadEnv();
    expect(env2.getRedisUrl()).toBeNull();
  });

  it("isRateLimitRedisEnabled reflects REDIS_URL", async () => {
    process.env.REDIS_URL = "redis://x";
    expect((await loadEnv()).isRateLimitRedisEnabled()).toBe(true);
    delete process.env.REDIS_URL;
    expect((await loadEnv()).isRateLimitRedisEnabled()).toBe(false);
  });

  it("detects production and test modes", async () => {
    process.env.NODE_ENV = "production";
    const prod = await loadEnv();
    expect(prod.isProduction()).toBe(true);
    expect(prod.isTest()).toBe(false);
    process.env.NODE_ENV = "test";
    const test = await loadEnv();
    expect(test.isProduction()).toBe(false);
    expect(test.isTest()).toBe(true);
  });

  it("getJwtSecret validates presence and length", async () => {
    delete process.env.JWT_SECRET;
    const env = await loadEnv();
    expect(() => env.getJwtSecret()).toThrow(/JWT_SECRET/);
    process.env.JWT_SECRET = "short";
    expect(() => env.getJwtSecret()).toThrow(/at least 16/);
    process.env.JWT_SECRET = "a".repeat(16);
    expect(env.getJwtSecret()).toBe("a".repeat(16));
  });

  it("getJwtExpiresIn and refresh expiry have defaults", async () => {
    delete process.env.JWT_EXPIRES_IN;
    delete process.env.REFRESH_TOKEN_EXPIRES_IN;
    const env = await loadEnv();
    expect(env.getJwtExpiresIn()).toBe("15m");
    expect(env.getRefreshTokenExpiresIn()).toBe("30d");
    process.env.JWT_EXPIRES_IN = " 5m ";
    process.env.REFRESH_TOKEN_EXPIRES_IN = " 7d ";
    const env2 = await loadEnv();
    expect(env2.getJwtExpiresIn()).toBe("5m");
    expect(env2.getRefreshTokenExpiresIn()).toBe("7d");
  });

  it("getSessionCacheTtlMs handles defaults, bounds, and invalid values", async () => {
    delete process.env.SESSION_CACHE_TTL_MS;
    const env = await loadEnv();
    expect(env.getSessionCacheTtlMs()).toBe(30_000);
    process.env.SESSION_CACHE_TTL_MS = "0";
    expect((await loadEnv()).getSessionCacheTtlMs()).toBe(0);
    process.env.SESSION_CACHE_TTL_MS = "600000";
    expect((await loadEnv()).getSessionCacheTtlMs()).toBe(600000);
    process.env.SESSION_CACHE_TTL_MS = "-1";
    expect((await loadEnv()).getSessionCacheTtlMs()).toBe(30_000);
    process.env.SESSION_CACHE_TTL_MS = "600001";
    expect((await loadEnv()).getSessionCacheTtlMs()).toBe(30_000);
    process.env.SESSION_CACHE_TTL_MS = "abc";
    expect((await loadEnv()).getSessionCacheTtlMs()).toBe(30_000);
  });

  it("getBcryptRounds clamps and defaults", async () => {
    delete process.env.BCRYPT_ROUNDS;
    expect((await loadEnv()).getBcryptRounds()).toBe(10);
    process.env.BCRYPT_ROUNDS = "12";
    expect((await loadEnv()).getBcryptRounds()).toBe(12);
    process.env.BCRYPT_ROUNDS = "1";
    expect((await loadEnv()).getBcryptRounds()).toBe(10);
    process.env.BCRYPT_ROUNDS = "99";
    expect((await loadEnv()).getBcryptRounds()).toBe(15);
    process.env.BCRYPT_ROUNDS = "x";
    expect((await loadEnv()).getBcryptRounds()).toBe(10);
  });

  it("allowConcurrentSessions is true only when env is true", async () => {
    process.env.ALLOW_CONCURRENT_SESSIONS = "true";
    expect((await loadEnv()).allowConcurrentSessions()).toBe(true);
    process.env.ALLOW_CONCURRENT_SESSIONS = "false";
    expect((await loadEnv()).allowConcurrentSessions()).toBe(false);
  });

  it("getPort validates range and defaults", async () => {
    delete process.env.PORT;
    expect((await loadEnv()).getPort()).toBe(3000);
    process.env.PORT = "8080";
    expect((await loadEnv()).getPort()).toBe(8080);
    process.env.PORT = "0";
    expect((await loadEnv()).getPort()).toBe(3000);
    process.env.PORT = "65536";
    expect((await loadEnv()).getPort()).toBe(3000);
    process.env.PORT = "nope";
    expect((await loadEnv()).getPort()).toBe(3000);
  });

  it("getCorsOrigins parses and filters", async () => {
    process.env.CORS_ORIGIN = " http://a.com, ,http://b.com ";
    expect((await loadEnv()).getCorsOrigins()).toEqual([
      "http://a.com",
      "http://b.com",
    ]);
    delete process.env.CORS_ORIGIN;
    expect((await loadEnv()).getCorsOrigins()).toEqual([
      "http://localhost:3000",
      "http://localhost:5173",
    ]);
  });

  it("getAppBaseUrl trims trailing slashes and defaults", async () => {
    delete process.env.APP_BASE_URL;
    expect((await loadEnv()).getAppBaseUrl()).toBe("http://localhost:8080");
    process.env.APP_BASE_URL = " https://app.example.com/// ";
    expect((await loadEnv()).getAppBaseUrl()).toBe("https://app.example.com");
  });

  it("isSmtpConfigured requires all fields", async () => {
    delete process.env.SMTP_HOST;
    delete process.env.SMTP_USER;
    delete process.env.SMTP_PASS;
    delete process.env.EMAIL_FROM;
    expect((await loadEnv()).isSmtpConfigured()).toBe(false);
    process.env.SMTP_HOST = "h";
    process.env.SMTP_USER = "u";
    process.env.SMTP_PASS = "p";
    process.env.EMAIL_FROM = "f";
    expect((await loadEnv()).isSmtpConfigured()).toBe(true);
  });

  it("rate limit getters validate positive ints", async () => {
    delete process.env.AUTH_RATE_LIMIT_MAX;
    delete process.env.AI_RATE_LIMIT_PER_USER;
    delete process.env.API_RATE_LIMIT_MAX;
    const env = await loadEnv();
    expect(env.getAuthRateLimitMax()).toBe(10);
    expect(env.getAiRateLimitPerUser()).toBe(20);
    expect(env.getApiRateLimitMax()).toBe(300);
    process.env.AUTH_RATE_LIMIT_MAX = "5";
    process.env.AI_RATE_LIMIT_PER_USER = "7";
    process.env.API_RATE_LIMIT_MAX = "100";
    const env2 = await loadEnv();
    expect(env2.getAuthRateLimitMax()).toBe(5);
    expect(env2.getAiRateLimitPerUser()).toBe(7);
    expect(env2.getApiRateLimitMax()).toBe(100);
    process.env.AUTH_RATE_LIMIT_MAX = "0";
    process.env.AI_RATE_LIMIT_PER_USER = "-1";
    process.env.API_RATE_LIMIT_MAX = "bad";
    const env3 = await loadEnv();
    expect(env3.getAuthRateLimitMax()).toBe(10);
    expect(env3.getAiRateLimitPerUser()).toBe(20);
    expect(env3.getApiRateLimitMax()).toBe(300);
  });

  it("AI config getters return defaults and normalized values", async () => {
    delete process.env.AI_PROVIDER;
    delete process.env.AI_MODEL;
    delete process.env.AI_BASE_URL;
    delete process.env.AI_API_KEY;
    delete process.env.AI_MAX_TOKENS;
    delete process.env.AI_TIMEOUT_MS;
    const env = await loadEnv();
    expect(env.getAiProvider()).toBe("mock");
    expect(env.getAiModel()).toBe("mock-model");
    expect(env.getAiBaseUrl()).toBe("https://api.openai.com/v1");
    expect(env.getAiApiKey()).toBeNull();
    expect(env.getAiMaxTokens()).toBe(400);
    expect(env.getAiTimeoutMs()).toBe(15000);

    process.env.AI_PROVIDER = " OpenAI ";
    process.env.AI_MODEL = " gpt-4.1 ";
    process.env.AI_BASE_URL = " https://example.com/v1/// ";
    process.env.AI_API_KEY = " key ";
    process.env.AI_MAX_TOKENS = "1024";
    process.env.AI_TIMEOUT_MS = "5000";
    const env2 = await loadEnv();
    expect(env2.getAiProvider()).toBe("openai");
    expect(env2.getAiModel()).toBe("gpt-4.1");
    expect(env2.getAiBaseUrl()).toBe("https://example.com/v1");
    expect(env2.getAiApiKey()).toBe("key");
    expect(env2.getAiMaxTokens()).toBe(1024);
    expect(env2.getAiTimeoutMs()).toBe(5000);

    process.env.AI_PROVIDER = "anthropic";
    delete process.env.AI_MODEL;
    process.env.AI_MAX_TOKENS = "1";
    process.env.AI_TIMEOUT_MS = "999999";
    const env3 = await loadEnv();
    expect(env3.getAiModel()).toBe("gpt-4o-mini");
    expect(env3.getAiMaxTokens()).toBe(400);
    expect(env3.getAiTimeoutMs()).toBe(15000);
  });

  it("shouldTrustProxy and getMongoUri read env", async () => {
    process.env.TRUST_PROXY = "true";
    process.env.MONGODB_URI = " mongodb://localhost:27017/db ";
    const env = await loadEnv();
    expect(env.shouldTrustProxy()).toBe(true);
    expect(env.getMongoUri()).toBe("mongodb://localhost:27017/db");
    process.env.TRUST_PROXY = "false";
    delete process.env.MONGODB_URI;
    const env2 = await loadEnv();
    expect(env2.shouldTrustProxy()).toBe(false);
    expect(env2.getMongoUri()).toBeNull();
  });
});

describe("assertRuntimeEnv", () => {
  it("throws for missing/short JWT secret", async () => {
    process.env.NODE_ENV = "test";
    delete process.env.JWT_SECRET;
    const env = await loadEnv();
    expect(() => env.assertRuntimeEnv()).toThrow(/JWT_SECRET/);
  });

  it("collects multiple problems", async () => {
    process.env.NODE_ENV = "production";
    delete process.env.JWT_SECRET;
    process.env.CAPTCHA_ENABLED = "true";
    delete process.env.TURNSTILE_SECRET_KEY;
    process.env.AI_PROVIDER = "openai";
    delete process.env.AI_API_KEY;
    delete process.env.CORS_ORIGIN;
    const env = await loadEnv();
    expect(() => env.assertRuntimeEnv()).toThrow(/Invalid configuration/);
    try {
      env.assertRuntimeEnv();
    } catch (err: any) {
      expect(err.message).toMatch(/JWT_SECRET/);
      expect(err.message).toMatch(/TURNSTILE_SECRET_KEY/);
      expect(err.message).toMatch(/AI_API_KEY/);
      expect(err.message).toMatch(/CORS_ORIGIN/);
    }
  });

  it("requires captcha in production and cors origin", async () => {
    process.env.NODE_ENV = "production";
    process.env.JWT_SECRET = "a".repeat(20);
    process.env.CAPTCHA_ENABLED = "false";
    process.env.CORS_ORIGIN = "https://app.example.com";
    process.env.AI_PROVIDER = "mock";
    const env = await loadEnv();
    expect(() => env.assertRuntimeEnv()).toThrow(/CAPTCHA_ENABLED/);
  });

  it("passes when production config is valid", async () => {
    process.env.NODE_ENV = "production";
    process.env.JWT_SECRET = "a".repeat(20);
    process.env.CAPTCHA_ENABLED = "true";
    process.env.TURNSTILE_SECRET_KEY = "secret";
    process.env.CORS_ORIGIN = "https://app.example.com";
    process.env.AI_PROVIDER = "mock";
    const env = await loadEnv();
    expect(() => env.assertRuntimeEnv()).not.toThrow();
  });

  it("reports non-mock AI provider without key", async () => {
    process.env.NODE_ENV = "test";
    process.env.JWT_SECRET = "a".repeat(20);
    process.env.AI_PROVIDER = "openai";
    delete process.env.AI_API_KEY;
    const env = await loadEnv();
    expect(() => env.assertRuntimeEnv()).toThrow(/AI_API_KEY/);
  });
});
