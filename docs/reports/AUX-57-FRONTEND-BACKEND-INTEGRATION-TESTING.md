# AUX-57 Frontend and Backend Integration Testing — Investigation

Date: 11 November 2026 (sprint bug-fix pass: AUX-76, AUX-77)
Branch: `feature/enterprise-cicd-pipeline`
Scope: Jira tickets AUX-57 (spike: frontend/backend integration testing) and the two attached bug fixes AUX-76 (CORS preflight / Authorization header) and AUX-77 (payload mismatch in API response parsing).
Method: static audit of the full HTTP contract surface (every `ApiClient` call site vs the Express routes/controllers that serve it), live verification of CORS behaviour against the production bundle, and inventory of the existing test layers.

## Executive summary

1. **The contract surface is consistent.** Every endpoint the Flutter client
   calls was audited against its Express handler; response-envelope reads,
   field names, enum casing and error-code handling all match (matrix
   below). AUX-77's "payload mismatch" is resolved in the current tree by the
   defensive parsing already merged (`\`_id\` ?? \`id\``, `payload is Map ? payload['items'] : payload`, `data['data'] ?? data`, tolerance for missing `updatedAt`).
2. **CORS works as designed and was verified live.** Preflight from an
   allow-listed origin returns 204 with `Authorization` in
   `Access-Control-Allow-Headers`; non-allow-listed origins get 403
   `CORS_FORBIDDEN` with no `Access-Control-Allow-Origin`. AUX-76's fix
   (explicit allow-list incl. `Authorization`, credentials, 204 preflight,
   `optionsSuccessStatus`) is in place and effective.
3. **Test layers exist but have real gaps.** Backend "integration" tests run
   in-process with mocked Mongoose models; there is no test that boots
   `dist/server.js` and speaks real HTTP, no frontend-driven E2E, and no CI
   job that exercises the two apps against each other over a socket.
   Recommendations below.

## Test layers — inventory

| Layer | Where | Runner | Notes |
|---|---|---|---|
| Backend unit | `backend/tests/unit/**` | vitest | 195 tests pass (incl. new `getPort()` specs) |
| Backend integration | `backend/tests/integration/*.test.ts` (auth, session, ai) | vitest + supertest | Models mocked via `vi.mock`; exercises route → controller → service → error mapping, not the DB |
| Backend contract | `backend/tests/contract/task.pact.test.ts`, `backend/pacts/` | vitest + PactV3 | Consumer-driven pact for tasks; run as part of `vitest run` |
| Frontend unit/widget | `frontend/test/**` | flutter test | ~270–276 tests per project notes; frontend tests not re-executed in this pass |
| Smoke (post-deploy) | `scripts/smoke-test.mjs <baseURL>` | node | Runs in `deploy-production.yml` after the health poll; checks deploy, not deep contracts |
| CI static/build | backend `format:check`, `lint`, `test:coverage`, `build`; frontend `flutter analyze`, `flutter test --coverage`; Docker build + Trivy | GitHub Actions | No cross-app integration stage |

## Frontend ↔ backend contract matrix (audit output)

| Client call (Flutter) | Backend route → controller | Wire envelope | Client parse | Verdict |
|---|---|---|---|---|
| `POST /api/auth/signup` | `auth.routes.ts` → `authController.signup` | `{ token, user }` (201) | `Session.fromApi` | OK |
| `POST /api/auth/login` | `auth.routes.ts` → `authController.login` | `{ token, user }` (200) | `Session.fromApi` | OK |
| `POST /api/auth/forgot-password` | `auth.routes.ts` → `forgotPassword` | `{ message }` | body ignored | OK |
| `POST /api/auth/reset-password` | `auth.routes.ts` → `resetPassword` | `{ message }` | body ignored | OK |
| `GET /api/auth/me` | `auth.routes.ts` → `me` | `{ user }` | status only | OK |
| `POST /api/auth/logout` | `auth.routes.ts` → `logout` | 204 | void | OK |
| `POST /api/ai/chat` | `ai/ai.routes.ts` → `chat` | `{ reply?, … }` → `createChatReply` | `data['reply']` | OK |
| `POST /api/ai/draft` | `ai/ai.routes.ts` → `taskDraft` | `{ reply, draft{…}, clarification }` | `data['draft']` map | OK |
| `GET /api/tasks?page&limit` | `task.routes.ts` → `taskController.list` | `{ message, data: Task[], pagination{page,limit,totalItems,totalPages,hasNextPage} }` | `TaskApiMapper.listFromApi(data['data'])`; loops pages on `pagination.hasNextPage` | OK |
| `POST /api/tasks` | `task.routes.ts` → `create` | `{ message, data: Task }` (201) | via `ApiClient.postJson`; `_id` UUID string | OK |
| `PATCH /api/tasks/:id` | `task.routes.ts` → `update` | `{ message, data: Task }` (200) or 409 `{ error, code: "TASK_CONFLICT" }` | optimistic concurrency via `expectedUpdatedAt`; 409 → conflict flow | OK |
| `DELETE /api/tasks/:id` | `task.routes.ts` → `remove` | 204 | void | OK |
| `GET/POST /api/groups`, `PATCH/DELETE /api/groups/:id` | `groups/core/group.controller.ts` | `{ success: true, data: { items\|group… } }` | `payload is Map ? payload['items'] : payload`; `StudyGroup.tryFromJson(...)` (`groupId` → `_id` → `id`) | OK |
| `GET /api/groups/:id/members` | `groups/member/member.controller.ts` | `{ message, data: Member[], pagination }` | `data` as List | OK |
| `POST /api/invitations` | `groups/invitation/invitation.controller.ts` | `{ message, data: { invitation{invitationId, groupId, email, role, expiresAt}, delivery, invitationToken? } }` | `GroupInvitation.tryFromJson` | OK |
| `POST /api/invitations/accept` | `groups/invitation/invitation.controller.ts` | `{ message, data }` | body ignored | OK |
| `GET/POST /api/calendar`, `GET /api/calendar/conflicts` | `calendar/calendar.controller.ts` | `{ success: true, data }` (conflicts: `data.conflictingEvents`) | `data['data']`; `CalendarEvent.tryFromJson` | OK |
| `sync_service` → tasks endpoints | same as tasks | same | `data['data'] ?? data` for single task; 409-codes `TASK_CONFLICT`/`TASK_ALREADY_EXISTS` → conflict resolution | OK |
| Error body (all modules) | `middleware/errorHandler.ts` | `{ error, code, details? }` | client reads `code` first, never renders 5xx bodies | OK |

### Envelope inconsistency (design debt, not a bug)

Modules emit three different success shapes: `{ success, data }` (calendar,
groups), `{ message, data, pagination? }` (tasks, members, invitations), and
bare `{ token, user }` / `{ user }` (auth). The client compensates
per-endpoint, which is why all current calls succeed. Risk: a new client or a
future endpoint copy-pastes the wrong shape and breaks parsing — AUX-77's
class of bug. Recommendation A-2 below.

Error responses are uniform (`{ error, code, details? }` from `AppError` /
`errorHandler`), and the client surfaces `code` (`TASK_CONFLICT`,
`TASK_ALREADY_EXISTS`, `CORS_FORBIDDEN`, `CAPTCHA_FAILED`) where retry or
conflict logic depends on it.

## AUX-76 — CORS preflight and Authorization header (verified live)

Configuration (`src/config/security.ts`): origin allow-list (production
requires `CORS_ORIGIN` env, enforced by `assertRuntimeEnv`), `credentials: true`,
methods incl. OPTIONS, `allowedHeaders` incl. `Content-Type`, `Authorization`,
`X-Captcha-Token`, `X-Request-Id`, `maxAge: 600`, `optionsSuccessStatus: 204`.
Disallowed origins produce `AppError(403, "CORS_FORBIDDEN")` **before** any
route handler — correct.

Live probes against the production bundle (`NODE_ENV=production`,
`PORT=10000`, `CORS_ORIGIN=https://app.example.com`):

```
OPTIONS /api/auth/login   Origin: https://app.example.com
  Access-Control-Request-Headers: authorization, content-type
→ 204 No Content
  Access-Control-Allow-Origin: https://app.example.com
  Access-Control-Allow-Credentials: true
  Access-Control-Allow-Methods: GET,POST,PUT,PATCH,DELETE,OPTIONS
  Access-Control-Allow-Headers: Content-Type,Authorization,X-Captcha-Token,X-Request-Id
  Access-Control-Max-Age: 600

OPTIONS /api/auth/login   Origin: https://evil.example.com   → 403 {"error":"Origin not allowed","code":"CORS_FORBIDDEN"}
GET     /api/health      Origin: https://evil.example.com   → 403 {"error":"Origin not allowed","code":"CORS_FORBIDDEN"}
GET     /api/health      (no Origin — curl/server-to-server) → 200 {"status":"ok"}
```

Preflight success requires all of: `OPTIONS` allowed by the cors middleware
(yes, `optionsSuccessStatus: 204`), `Authorization` in `allowedHeaders` (yes),
allow-listed origin (dashboard/env), and no `Cache-Control` interference on
`/api/auth` (the `no-store` header is set for caching, not CORS — harmless to
preflight). Remaining note: Flutter **web** dev runs on a random Chrome port;
local development should use `CORS_ORIGIN=http://localhost:8080` (docker
nginx) or explicit `--web-port`, matching `.env.example`.

## AUX-77 — Payload mismatch in API response parsing (verified by audit)

Changes that resolved the symptom class (already merged): tolerant id read
(`_id ?? id`), list/envelope fallbacks (`data['data'] ?? data`,
`payload['items'] ?? payload`), `expectedUpdatedAt` compare-and-swap 409 path,
UUID `_id` (no ObjectId serialisation leaks), `toJSON` transform stripping
`deletedAt`, client never renders 5xx bodies and keys off `code`. No
mismatch found in any live call site in the current tree; nothing to fix in
this pass. If a mismatch resurfaces in review, capture the exact response of
the failing endpoint — it will be one of the three envelopes in the table
above.

## Gaps — what integration testing does not yet cover

1. **No cross-process test.** All backend integration tests mock Mongoose;
   no test binds a real server socket and performs HTTP round-trips (exactly
   the class of failure that made AUX-85 invisible). See A-3.
2. **No frontend-driven API test.** Flutter tests never touch HTTP (no
   `MockClient`-based tests assert the `{success,data}` vs `{message,data}`
   shapes); pact covers only the task module.
3. **Envelope drift risk.** Three success shapes coexist; nothing in CI
   enforces a single envelope or a schema per route (OpenAPI doc exists in
   non-production at `/api-docs` but is not asserted against requests).
4. **Deploy smoke is shallow.** `scripts/smoke-test.mjs` checks the deploy is
   reachable/healthy; it does not exercise auth → task CRUD round-trip
   against the deployed backend.
5. **CORS not in CI.** Allow-list correctness is verified by hand (this
   report); no CI job asserts preflight behaviour on a PR that touches
   `config/security.ts`.

## Recommendations / action items

| # | Action | Priority |
|---|---|---|
| A-1 | Merge this branch; AUX-76/AUX-77 → Done with this report as evidence; AUX-57 → Done | Now |
| A-2 | Standardize response envelope behind one helper (`sendOk(res, data, {message, pagination})`); deprecate bare `{ token, user }` into `{ data: { token, user } }` with a deprecation window; update the three call-site parsers | Medium (separate PR) |
| A-3 | Add `tests/integration/http-stack.test.ts`: boot the compiled app on an ephemeral port (`app.listen(0)`) and assert health, auth login shape, task create/list round-trip with mocked DB but real HTTP/TCP; run in CI | Medium |
| A-4 | Extend `scripts/smoke-test.mjs`: login (seed test user or mock secret) → create task → list tasks → delete task; fail deploy on mismatch | Medium |
| A-5 | Add `dart test` for `ApiClient` using `package:http/testing.dart` `MockClient`: envelope decode for all matrix rows; run in `flutter test` | Medium |
| A-6 | Run pact verification on CI for the frontend consumer too (frontend already builds pact files under `pacts/`) | Low |
| A-7 | Add a CORS preflight assertion (curl-style) to CI backend job gated on paths `config/security.ts`, `app.ts` | Low |
| A-8 | Keep Swagger `/api-docs` out of production (already the case) and consider exporting the OpenAPI document into the repo for contract review | Low |
| A-9 | Document dev flow: `docker compose up --build` + `flutter run -d chrome --web-port=8080` vs nginx proxy (`/api/` → `backend:3000`) so CORS is never needed between same-origin web and API on :8080 | Info |

## Ticket mapping

- **AUX-76** — verified fixed (configuration + live probes above). Ready to move In Review → Done after human re-check.
- **AUX-77** — verified by static audit; no mismatch reproducible in current tree. Ready to move In Review → Done.
- **AUX-57** — answered: testing strategy and gaps above; A-2…A-7 define the uplift. No code changes required to close the spike beyond this report.
