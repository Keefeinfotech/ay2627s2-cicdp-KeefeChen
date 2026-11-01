/**
 * File Name: index.ts
 * Description: Exposes the public interface of the Users module.
 * Author: Keefe Chen
 */

/**
 * Routes
 */
export { default as userRoutes } from "./user.routes.js";

/**
 * Services
 */
export { userService } from "./user.service.js";

/**
 * Repository
 */
export { userRepository } from "./user.repository.js";

/**
 * Model
 */
export { User } from "./user.model.js";

/**
 * Constants
 */
export {
  USER_ROLES,
  USER_STATUSES,
} from "./user.types.js";

/**
 * Domain and API types
 */
export type {
  UserRole,
  UserStatus,
  CreateUserInput,
  UpdateOwnProfileInput,
  PublicUser,
  PublicUserSummary,
} from "./user.types.js";