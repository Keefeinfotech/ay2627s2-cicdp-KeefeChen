/**
 * File Name: express.d.ts
 * Description: Extends Express Request with authenticated user information, custom body, query, and params.
 * Author: Keefe Chen
 */

import type { UserRole } from "../../src/constants/security.js";

declare global {
  namespace Express {
    interface Request {
      // Authenticated user properties
      userId?: string;
      userEmail?: string;
      userRole?: UserRole;
      /** Session id (JWT id) of the token that authenticated this request. */
      sessionId?: string;
      requestId: string;

      // Custom payload typing extensions (optional defaults)
      body: any;
      query: { [key: string]: string | string[] | undefined };
      params: { [key: string]: string };
    }
  }
}

export {};
