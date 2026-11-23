/*
 * File Name: swagger.ts
 * Description: Configures Swagger UI and OpenAPI documentation for the API.
 * Author: Keefe Chen
 * Date: 27 October 2026
 */

import swaggerUi from "swagger-ui-express";
import type { OpenAPIV3 } from "openapi-types";

const userSchema: OpenAPIV3.SchemaObject = {
  type: "object",
  properties: {
    id: { type: "string" },
    name: { type: "string", nullable: true },
    email: { type: "string", format: "email" },
  },
};

/** Common shape for read-only, bearer-authenticated endpoints. */
const readEndpoint = (
  summary: string,
  description: string,
): OpenAPIV3.PathItemObject => ({
  get: {
    summary,
    security: [{ bearerAuth: [] }],
    responses: { "200": { description } },
  },
});

/** Common shape for single-field update endpoints. */
const updateEndpoint = (
  summary: string,
  description: string,
): OpenAPIV3.PathItemObject => ({
  patch: {
    summary,
    security: [{ bearerAuth: [] }],
    responses: { "200": { description } },
  },
});

export const swaggerDocument: OpenAPIV3.Document = {
  openapi: "3.0.3",
  info: {
    title: "Personal Secretary API",
    version: "1.0.0",
    description:
      "Auxilia API — tasks, reminders, calendar, AI assistant, analytics, notifications, preferences and offline sync. Canonical prefix is /api/v1 (legacy /api alias retained).",
  },
  servers: [
    {
      url: "http://localhost:3000",
      description: "Local development server",
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" },
    },
    schemas: {
      User: userSchema,
      Error: {
        type: "object",
        properties: {
          error: { type: "string" },
          code: { type: "string" },
        },
      },
    },
  },
  paths: {
    "/api/health": {
      get: {
        summary: "Check API health",
        responses: { "200": { description: "API is running successfully" } },
      },
    },
    "/api/auth/signup": {
      post: {
        summary: "Create an account",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  name: { type: "string", maxLength: 80 },
                  email: { type: "string", format: "email" },
                  password: { type: "string", minLength: 8, maxLength: 128 },
                  captchaToken: {
                    type: "string",
                    description:
                      "Cloudflare Turnstile token. Required when CAPTCHA_ENABLED=true.",
                  },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Account created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    token: { type: "string" },
                    refreshToken: {
                      type: "string",
                      description:
                        "Opaque refresh token; send to /api/auth/refresh to renew the access token.",
                    },
                    user: { $ref: "#/components/schemas/User" },
                  },
                },
              },
            },
          },
          "400": { description: "Validation failed" },
          "409": { description: "Email already registered" },
        },
      },
    },
    "/api/auth/login": {
      post: {
        summary: "Sign in",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "password"],
                properties: {
                  email: { type: "string", format: "email" },
                  password: { type: "string" },
                  captchaToken: {
                    type: "string",
                    description:
                      "Cloudflare Turnstile token. Required when CAPTCHA_ENABLED=true.",
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Signed in",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    token: { type: "string" },
                    refreshToken: { type: "string" },
                    user: { $ref: "#/components/schemas/User" },
                  },
                },
              },
            },
          },
          "400": { description: "Validation failed or CAPTCHA rejected" },
          "401": { description: "Invalid credentials" },
          "429": { description: "Too many attempts" },
        },
      },
    },
    "/api/auth/refresh": {
      post: {
        summary: "Renew an expired access token",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["refreshToken"],
                properties: {
                  refreshToken: { type: "string", maxLength: 512 },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description:
              "New access/refresh token pair (the old refresh token is rotated)",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    token: { type: "string" },
                    refreshToken: { type: "string" },
                    user: { $ref: "#/components/schemas/User" },
                  },
                },
              },
            },
          },
          "400": { description: "Validation failed" },
          "401": {
            description:
              "Unknown, expired or revoked refresh token; a replayed rotated token revokes the session",
          },
          "429": { description: "Too many attempts" },
        },
      },
    },
    "/api/auth/me": {
      get: {
        summary: "Get the signed-in user",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Current user",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { user: { $ref: "#/components/schemas/User" } },
                },
              },
            },
          },
          "401": {
            description:
              "Missing/expired token, or the session was replaced by a newer login",
          },
        },
      },
    },
    "/api/auth/logout": {
      post: {
        summary: "End the current session",
        security: [{ bearerAuth: [] }],
        responses: {
          "204": { description: "Session ended" },
          "401": { description: "Authentication required" },
        },
      },
    },
    "/api/auth/sessions": {
      get: {
        summary: "List this account's signed-in devices",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Active sessions, newest first",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    sessions: {
                      type: "array",
                      items: {
                        type: "object",
                        properties: {
                          id: { type: "string" },
                          current: {
                            type: "boolean",
                            description: "True for the calling session",
                          },
                          userAgent: {
                            type: "string",
                            nullable: true,
                          },
                          createdAt: { type: "string", format: "date-time" },
                          lastUsedAt: { type: "string", format: "date-time" },
                          expiresAt: { type: "string", format: "date-time" },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
          "401": { description: "Authentication required" },
        },
      },
    },
    "/api/auth/sessions/{id}": {
      delete: {
        summary: "Revoke one session (sign out a single device)",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string" },
            description: "Session id from GET /api/auth/sessions",
          },
        ],
        responses: {
          "204": { description: "Session revoked (idempotent)" },
          "401": { description: "Authentication required" },
          "404": { description: "No such session for this account" },
        },
      },
    },
    "/api/ai/chat": {
      post: {
        summary: "Send a message to the assistant",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["message"],
                properties: {
                  message: { type: "string", maxLength: 1000 },
                  context: {
                    type: "array",
                    maxItems: 10,
                    items: {
                      type: "object",
                      required: ["role", "content"],
                      properties: {
                        role: { type: "string", enum: ["user", "assistant"] },
                        content: { type: "string", maxLength: 1000 },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": { description: "Assistant reply" },
          "401": { description: "Authentication required" },
        },
      },
    },
    "/api/ai/draft": {
      post: {
        summary: "Prepare a task draft for user review",
        description:
          "Returns a Zod-validated suggestion and never writes a task. The caller must confirm through the task API.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["message"],
                properties: {
                  message: { type: "string", minLength: 1, maxLength: 1000 },
                  context: {
                    type: "array",
                    maxItems: 10,
                    items: { type: "object" },
                  },
                  currentDate: { type: "string", format: "date" },
                  utcOffsetMinutes: {
                    type: "integer",
                    minimum: -840,
                    maximum: 840,
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Task suggestion or clarification request",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  required: ["reply", "draft", "clarification"],
                  properties: {
                    reply: { type: "string" },
                    draft: {
                      type: "object",
                      nullable: true,
                      properties: {
                        title: { type: "string", maxLength: 150 },
                        description: { type: "string", nullable: true },
                        course: { type: "string", nullable: true },
                        dueDate: {
                          type: "string",
                          format: "date",
                          nullable: true,
                        },
                        priority: {
                          type: "string",
                          enum: ["low", "medium", "high"],
                          nullable: true,
                        },
                      },
                    },
                    clarification: { type: "string", nullable: true },
                  },
                },
              },
            },
          },
          "400": { description: "Invalid request or AI response" },
          "401": { description: "Authentication required" },
          "429": { description: "AI request rate limit exceeded" },
          "502": {
            description:
              "AI provider unavailable or returned an invalid result",
          },
        },
      },
    },
    "/api/v1/health/live": {
      get: {
        summary: "Liveness probe",
        responses: { "200": { description: "Process is up" } },
      },
    },
    "/api/v1/health/ready": {
      get: {
        summary: "Readiness probe (database reachable)",
        responses: {
          "200": { description: "Ready to serve traffic" },
          "503": { description: "Not ready (database unavailable)" },
        },
      },
    },
    "/api/auth/change-password": {
      post: {
        summary: "Change password (current session kept; others revoked)",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["currentPassword", "newPassword"],
                properties: {
                  currentPassword: { type: "string" },
                  newPassword: { type: "string", minLength: 12 },
                },
              },
            },
          },
        },
        responses: {
          "200": { description: "Password updated" },
          "401": {
            description: "Authentication required or wrong current password",
          },
        },
      },
    },
    "/api/auth/logout-all": {
      post: {
        summary: "Sign out every device (including this one)",
        security: [{ bearerAuth: [] }],
        responses: {
          "204": { description: "All sessions revoked" },
          "401": { description: "Authentication required" },
        },
      },
    },
    "/api/users/me/email": {
      patch: {
        summary: "Change the account email (requires current password)",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "currentPassword"],
                properties: {
                  email: { type: "string", format: "email" },
                  currentPassword: { type: "string" },
                },
              },
            },
          },
        },
        responses: {
          "200": { description: "Email updated; marked unverified" },
          "403": { description: "Wrong current password" },
          "409": { description: "Email already registered" },
        },
      },
    },
    "/api/tasks/bulk": {
      post: {
        summary: "Bulk-create up to 100 tasks",
        security: [{ bearerAuth: [] }],
        responses: {
          "201": { description: "Bulk creation result with per-item outcomes" },
          "400": { description: "Validation failed" },
        },
      },
      delete: {
        summary: "Bulk soft-delete up to 100 tasks",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Bulk delete result" } },
      },
    },
    "/api/tasks/bulk/status": updateEndpoint(
      "Bulk-update the status of up to 100 tasks",
      "Bulk status update result",
    ),
    "/api/tasks/{taskId}/complete": {
      post: {
        summary: "Mark a task completed",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Task completed" },
          "404": { description: "Task not found" },
        },
      },
    },
    "/api/tasks/{taskId}/reopen": {
      post: {
        summary: "Reopen a completed task",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Task reopened" },
          "404": { description: "Task not found" },
        },
      },
    },
    "/api/tasks/{taskId}/status": updateEndpoint(
      "Set only the task status",
      "Status updated",
    ),
    "/api/tasks/{taskId}/priority": updateEndpoint(
      "Set only the task priority",
      "Priority updated",
    ),
    "/api/tasks/{taskId}/due-date": updateEndpoint(
      "Set (or clear, with null) the task due date",
      "Due date updated",
    ),
    "/api/tasks/{taskId}/reminders": {
      get: {
        summary: "List reminders attached to a task",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Task reminders" } },
      },
      post: {
        summary: "Attach a reminder to a task",
        security: [{ bearerAuth: [] }],
        responses: {
          "201": { description: "Reminder created" },
          "404": { description: "Task not found" },
        },
      },
    },
    "/api/reminders": {
      get: {
        summary: "List own reminders",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Own reminders, by dueAt" } },
      },
      post: {
        summary: "Create a reminder (supports recurrence)",
        security: [{ bearerAuth: [] }],
        responses: {
          "201": { description: "Reminder created" },
          "400": { description: "Validation failed" },
        },
      },
      delete: {
        summary: "Not implemented on the collection; use /{reminderId}",
        responses: {
          "405": { description: "Use DELETE /api/reminders/{reminderId}" },
        },
      },
    },
    "/api/reminders/upcoming": readEndpoint(
      "Upcoming enabled reminders within ?days= (1-90, default 7)",
      "Upcoming reminders",
    ),
    "/api/reminders/{reminderId}": {
      get: {
        summary: "Get a reminder (owner only)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "The reminder" },
          "404": { description: "Reminder not found" },
        },
      },
      patch: {
        summary: "Update a reminder (message/dueAt/recurrence/enabled)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Reminder updated" },
          "404": { description: "Reminder not found" },
        },
      },
      delete: {
        summary: "Delete a reminder (owner only)",
        security: [{ bearerAuth: [] }],
        responses: {
          "204": { description: "Deleted" },
          "404": { description: "Reminder not found" },
        },
      },
    },
    "/api/reminders/{reminderId}/status": updateEndpoint(
      "Enable/disable/complete-toggle a reminder",
      "Status updated",
    ),
    "/api/reminders/{reminderId}/complete": {
      post: {
        summary:
          "Mark a reminder completed (recurring reminders spawn the next occurrence)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Marked completed" },
          "404": { description: "Reminder not found" },
        },
      },
    },
    "/api/analytics/overview": readEndpoint(
      "Headline task statistics for the current user",
      "Overview counters",
    ),
    "/api/analytics/daily": readEndpoint(
      "Per-day created/completed counts (?days=1-90)",
      "Daily buckets",
    ),
    "/api/analytics/monthly": readEndpoint(
      "Per-month created/completed counts (?months=1-24)",
      "Monthly buckets",
    ),
    "/api/analytics/completion-rate": readEndpoint(
      "Completion rate over the trailing ?weeks=",
      "Completion rate",
    ),
    "/api/analytics/task-trends": readEndpoint(
      "Monthly trend with improving/declining/steady signal",
      "Trend buckets + direction",
    ),
    "/api/analytics/overdue": readEndpoint(
      "Open tasks past their due date (most overdue first)",
      "Overdue tasks",
    ),
    "/api/analytics/productivity-summary": readEndpoint(
      "Overview + streak for the productivity dashboard",
      "Productivity summary",
    ),
    "/api/analytics/weekly": readEndpoint(
      "Weekly created/completed buckets + streak",
      "Weekly buckets",
    ),
    "/api/notifications": {
      get: {
        summary: "List in-app notifications (?page&limit&read)",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Notifications + pagination" } },
      },
      delete: {
        summary: "Clear all notifications for the current user",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Cleared" } },
      },
    },
    "/api/notifications/unread-count": readEndpoint(
      "Number of unread notifications",
      "Unread count",
    ),
    "/api/notifications/read-all": updateEndpoint(
      "Mark every notification as read",
      "Marked",
    ),
    "/api/notifications/{notificationId}/read": {
      patch: {
        summary: "Mark one notification as read",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Marked" },
          "404": { description: "Not found" },
        },
      },
    },
    "/api/notifications/devices": {
      get: {
        summary: "List registered push devices",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Registered devices" } },
      },
      post: {
        summary: "Register (or refresh) a push device token",
        security: [{ bearerAuth: [] }],
        responses: { "201": { description: "Device registered" } },
      },
    },
    "/api/notifications/devices/{deviceId}": {
      delete: {
        summary: "Unregister a push device",
        security: [{ bearerAuth: [] }],
        responses: {
          "204": { description: "Unregistered" },
          "404": { description: "Device not found" },
        },
      },
    },
    "/api/preferences": {
      get: {
        summary: "Get (creating defaults if needed) the caller's preferences",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Preferences" } },
      },
      patch: {
        summary:
          "Update any preference sections (notifications/appearance/timezone/locale)",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Updated preferences" } },
      },
    },
    "/api/preferences/notifications": updateEndpoint(
      "Update notification preferences",
      "Updated",
    ),
    "/api/preferences/appearance": updateEndpoint(
      "Update appearance preferences (theme/fontScale)",
      "Updated",
    ),
    "/api/preferences/timezone": {
      patch: {
        summary: "Update the user timezone (IANA, validated)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Updated" },
          "400": { description: "Invalid time zone" },
        },
      },
    },
    "/api/sync/push": {
      post: {
        summary:
          "Push up to 50 idempotent operations (task.create/update/delete)",
        description:
          "Each operation carries a client-generated opId (UUID). Replays return the stored result; conflicts are reported per operation.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Per-operation results (applied/failed/conflict)",
          },
          "400": { description: "Validation failed" },
        },
      },
    },
    "/api/sync/batch": {
      post: {
        summary: "Alias of /api/sync/push",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Per-operation results" } },
      },
    },
    "/api/sync/pull": readEndpoint(
      "Incremental pull (alias of /api/sync/changes)",
      "Changes since cursor",
    ),
    "/api/sync/status": readEndpoint(
      "Server sync status (serverTime, supported operations)",
      "Sync status",
    ),
    "/api/sync/resolve-conflict": {
      post: {
        summary:
          "Resolve a client/server task conflict (server wins, or apply client state)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Resolved task" },
          "404": { description: "Task not found" },
        },
      },
    },
    "/api/assistant/interpret": {
      post: {
        summary:
          "Interpret a natural-language task request into a pending draft",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Draft + clarification; nothing is persisted" },
          "429": { description: "AI rate limit" },
          "502": { description: "AI provider unavailable" },
        },
      },
    },
    "/api/assistant/clarify": {
      post: {
        summary: "Re-interpret a pending draft with an additional answer",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Updated draft" },
          "404": { description: "Draft not found or expired" },
        },
      },
    },
    "/api/assistant/preview": {
      post: {
        summary: "Editable preview of a pending draft (optionally with edits)",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Preview" },
          "404": { description: "Draft not found or expired" },
        },
      },
    },
    "/api/assistant/confirm": {
      post: {
        summary:
          "Create the task from the pending draft (only path to persistence)",
        security: [{ bearerAuth: [] }],
        responses: {
          "201": { description: "Task created" },
          "404": { description: "Draft not found or expired" },
          "422": { description: "Draft is missing a title" },
        },
      },
    },
    "/api/assistant/cancel": {
      post: {
        summary: "Discard a pending draft",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Cancelled" },
          "404": { description: "Draft not found or expired" },
        },
      },
    },
    "/api/assistant/suggestions": {
      post: {
        summary: "Prompt suggestions derived from the caller's open tasks",
        security: [{ bearerAuth: [] }],
        responses: { "200": { description: "Suggested prompts" } },
      },
    },
  },
};

export { swaggerUi };
