/**
 * File Name: express.d.ts
 * Description: Extends Express Request with authenticated user information.
 * Author: Keefe Chen
 */

import type { UserRole } from "../../src/constants/security.js";

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      userEmail?: string;
      userRole?: UserRole;
      requestId: string;
    }
  }
}

export {};