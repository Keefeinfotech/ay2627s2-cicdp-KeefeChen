
import type { NextFunction, Request, Response } from "express";
import { ZodError, z, type ZodType } from "zod";

/**
 * Represents an individual validation error.
 */
interface FieldIssue {
  path: string;
  message: string;
}

/**
 * Converts Zod validation errors into a consistent response format.
 */
const toFieldIssues = (error: ZodError): FieldIssue[] =>
  error.issues.map((issue) => ({
    path: issue.path.join("."),
    message: issue.message,
  }));

/**
 * Validates the request body, query and route parameters.
 *
 * Expected schema structure:
 * {
 *   body: z.object(...),
 *   query: z.object(...).optional(),
 *   params: z.object(...).optional()
 * }
 */
export const validateRequest =
  (schema: ZodType) =>
  (req: Request, res: Response, next: NextFunction) => {
    try {
      const parsed = schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      }) as {
        body?: unknown;
        query?: unknown;
        params?: unknown;
      };

      // Replace request body with validated and parsed data.
      if (parsed.body !== undefined) {
        req.body = parsed.body;
      }

      // Replace route parameters with validated data.
      if (parsed.params !== undefined) {
        req.params = parsed.params as Request["params"];
      }

      // Replace query parameters with validated data.
      if (parsed.query !== undefined) {
        Object.defineProperty(req, "query", {
          value: parsed.query,
          writable: true,
          configurable: true,
        });
      }

      return next();
    } catch (err) {
      if (err instanceof ZodError) {
        return res.status(400).json({
          error: "Validation failed",
          code: "VALIDATION_ERROR",
          details: toFieldIssues(err),
        });
      }

      return next(err);
    }
  };

/**
 * Validates only req.body.
 *
 * Useful for POST, PUT and PATCH routes.
 *
 * Example:
 * validateBody(createGroupSchema)
 */
export const validateBody = (schema: ZodType) => {
  const requestSchema = z.object({
    body: schema,
    query: z.unknown().optional(),
    params: z.unknown().optional(),
  });

  return validateRequest(requestSchema);
};
