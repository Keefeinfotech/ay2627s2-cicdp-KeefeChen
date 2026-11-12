import helmet from "helmet";
import type { CorsOptions } from "cors";
import { getCorsOrigins, isProduction } from "./environment.js";
import { REQUEST_BODY_LIMIT } from "../constants/security.js";
import { AppError } from "../shared/utils/AppError.js";

export const helmetMiddleware = helmet({
  contentSecurityPolicy: isProduction() ? undefined : false,
  crossOriginEmbedderPolicy: false,
  hsts: isProduction()
    ? { maxAge: 15552000, includeSubDomains: true, preload: true }
    : false,
});

// Matches any origin on the loopback interface with any port, e.g.
// http://localhost:63488. Flutter's web dev server picks a random port on
// every run, which would otherwise fall outside the CORS_ORIGIN allowlist.
// Only used outside production, where strict allowlisting still applies.
const LOOPBACK_ORIGIN_PATTERN =
  /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d{1,5})?$/i;

const isLocalDevOrigin = (origin: string): boolean => {
  if (isProduction()) return false;
  return LOOPBACK_ORIGIN_PATTERN.test(origin);
};

export const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    if (!origin) return callback(null, true);
    if (getCorsOrigins().includes(origin)) return callback(null, true);
    if (isLocalDevOrigin(origin)) return callback(null, true);
    return callback(new AppError(403, "CORS_FORBIDDEN", "Origin not allowed"));
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: [
    "Content-Type",
    "Authorization",
    "X-Captcha-Token",
    "X-Request-Id",
  ],
  exposedHeaders: ["X-Request-Id"],
  maxAge: 600,
  optionsSuccessStatus: 204,
};

export const jsonBodyOptions = {
  limit: REQUEST_BODY_LIMIT,
  strict: true,
};

export const urlEncodedBodyOptions = {
  extended: true,
  limit: REQUEST_BODY_LIMIT,
};
