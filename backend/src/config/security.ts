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

const isLocalDevOrigin = (origin: string): boolean => {
  if (isProduction()) return false;
  return origin === 'http://localhost:3000' || origin === 'http://127.0.0.1:3000';
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
