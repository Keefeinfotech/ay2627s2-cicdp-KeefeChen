export class EnvError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EnvError";
  }
}

const MIN_JWT_SECRET_LENGTH = 16;

const stripTrailingSlashes = (value: string): string => {
  let end = value.length;
  while (end > 0 && value.charCodeAt(end - 1) === 47) end -= 1;
  return value.slice(0, end);
};

export const isProduction = (): boolean =>
  process.env.NODE_ENV === "production";

export const isTest = (): boolean => process.env.NODE_ENV === "test";

export const getJwtSecret = (): string => {
  const secret = process.env.JWT_SECRET?.trim();
  if (!secret || secret.length < MIN_JWT_SECRET_LENGTH) {
    throw new EnvError(
      `JWT_SECRET must be set to at least ${MIN_JWT_SECRET_LENGTH} characters`,
    );
  }
  return secret;
};

export const getJwtExpiresIn = (): string =>
  process.env.JWT_EXPIRES_IN?.trim() || "1d";

export const getBcryptRounds = (): number => {
  const parsed = Number(process.env.BCRYPT_ROUNDS);
  if (!Number.isInteger(parsed)) {
    return 10;
  }
  return Math.min(Math.max(parsed, 10), 15);
};

export const allowConcurrentSessions = (): boolean =>
  process.env.ALLOW_CONCURRENT_SESSIONS === "true";

export const getPort = (): number => {
  const parsed = Number(process.env.PORT);
  if (!Number.isInteger(parsed) || parsed < 1 || parsed > 65535) {
    return 3000;
  }
  return parsed;
};

export const getCorsOrigins = (): string[] =>
  (process.env.CORS_ORIGIN || "http://localhost:3000,http://localhost:5173")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

export const getAppBaseUrl = (): string =>
  stripTrailingSlashes(
    process.env.APP_BASE_URL?.trim() || "http://localhost:8080",
  );

export const isSmtpConfigured = (): boolean =>
  Boolean(
    process.env.SMTP_HOST?.trim() &&
    process.env.SMTP_USER?.trim() &&
    process.env.SMTP_PASS?.trim() &&
    process.env.EMAIL_FROM?.trim(),
  );

export const getAuthRateLimitMax = (): number => {
  const parsed = Number(process.env.AUTH_RATE_LIMIT_MAX);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 10;
};

export const getAiRateLimitPerUser = (): number => {
  const parsed = Number(process.env.AI_RATE_LIMIT_PER_USER);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 20;
};

export const getApiRateLimitMax = (): number => {
  const parsed = Number(process.env.API_RATE_LIMIT_MAX);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 300;
};

export const getAiProvider = (): string =>
  process.env.AI_PROVIDER?.trim().toLowerCase() || "mock";

export const getAiModel = (): string =>
  process.env.AI_MODEL?.trim() ||
  (getAiProvider() === "mock" ? "mock-model" : "gpt-4o-mini");

export const getAiBaseUrl = (): string =>
  stripTrailingSlashes(
    process.env.AI_BASE_URL?.trim() || "https://api.openai.com/v1",
  );

export const getAiApiKey = (): string | null =>
  process.env.AI_API_KEY?.trim() || null;

export const getAiMaxTokens = (): number => {
  const parsed = Number(process.env.AI_MAX_TOKENS);
  return Number.isInteger(parsed) && parsed >= 32 && parsed <= 4096
    ? parsed
    : 400;
};

export const getAiTimeoutMs = (): number => {
  const parsed = Number(process.env.AI_TIMEOUT_MS);
  return Number.isInteger(parsed) && parsed >= 1000 && parsed <= 60000
    ? parsed
    : 15000;
};

export const shouldTrustProxy = (): boolean =>
  process.env.TRUST_PROXY === "true";

export const getMongoUri = (): string | null =>
  process.env.MONGODB_URI?.trim() || null;

export const assertRuntimeEnv = (): void => {
  getJwtSecret();

  if (
    process.env.CAPTCHA_ENABLED === "true" &&
    !process.env.TURNSTILE_SECRET_KEY?.trim()
  ) {
    throw new EnvError(
      "CAPTCHA_ENABLED=true requires TURNSTILE_SECRET_KEY to be set",
    );
  }

  if (getAiProvider() !== "mock" && !getAiApiKey()) {
    throw new EnvError("AI_PROVIDER is not mock but AI_API_KEY is not set");
  }

  if (isProduction()) {
    if (process.env.CAPTCHA_ENABLED !== "true") {
      throw new EnvError("CAPTCHA_ENABLED must be 'true' in production");
    }
    if (!process.env.CORS_ORIGIN?.trim()) {
      throw new EnvError("CORS_ORIGIN must be set in production");
    }
  }
};
