/**
 * File Name: index.ts
 * Description: Public exports for the Auth module.
 * Author: Keefe Chen
 */

export { default as authRoutes } from "./auth.routes.js";

export { default as mfaRoutes } from "./mfa/mfa.routes.js";

export * as authService from "./auth.service.js";

export * from "./auth.types.js";
