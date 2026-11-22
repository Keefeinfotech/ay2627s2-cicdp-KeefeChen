# Auxilia API — Audit & Gap Analysis

Scope: full backend audit performed 2026-11-19 against the modular monolith at
`backend/src`. Response conventions are preserved: success `{ message, data }`
(frontends depend on this), errors `{ error, code, details? }`. `/api/v1/*` is
canonical; `/api/*` is the legacy alias.

## Existing (verified working, kept as-is)

| Module | Endpoints |
|---|---|
| Auth | `POST /auth/signup`, `/login`, `/refresh`, `/forgot-password`, `/reset-password`, `/logout`, `GET /auth/me`, `GET /auth/sessions`, `DELETE /auth/sessions/:id` |
| Users | `GET/PATCH/DELETE /users/me` |
| Tasks | `GET/POST /tasks`, `GET/PATCH/DELETE /tasks/:taskId` (pagination, filtering, text search, soft delete, optimistic concurrency) |
| AI | `POST /ai/chat`, `POST /ai/draft`, `GET /ai/today`, `GET /ai/tasks`, `POST /ai/create`, `/complete`, `/delete` |
| Reminders | `GET/POST /reminders`, `GET /reminders/pending`, `POST /reminders/:id/complete`, `DELETE /reminders/:id` |
| Calendar | `POST/GET /calendar`, `GET /calendar/conflicts`, `PATCH/DELETE /calendar/:id` |
| Analytics | `GET /analytics/weekly`, `GET /analytics/priority-suggestions`, `POST /analytics/priority-suggestions/apply` |
| Sync | `GET /sync/changes?since=` |
| Groups/Invitations/Roadmaps/Rubrics/Sessions/Progress/Audit/Feedback/Admin | full CRUD-ish surfaces (see README) |
| Health | `GET /health` (liveness only) |

## Gap analysis vs target

| Target endpoint(s) | Status |
|---|---|
| `POST /auth/change-password` | Missing → **implemented** |
| `POST /auth/logout-all` | Missing → **implemented** |
| `PATCH /users/me/email` | Missing → **implemented** |
| `PATCH /tasks/:taskId/status|priority|due-date` | Missing → **implemented** (delegate to `taskService.updateTask`) |
| `POST /tasks/:taskId/complete`, `/reopen` | Missing → **implemented** |
| `POST /tasks/bulk`, `PATCH /tasks/bulk/status`, `DELETE /tasks/bulk` | Missing → **implemented** |
| `GET /reminders/upcoming`, `PATCH /reminders/:id`, `GET/POST /tasks/:taskId/reminders` | Missing → **implemented** |
| Reminder recurrence + ownership (IDOR in complete/delete!) | Broken/missing → **fixed + implemented** |
| `/health/ready`, `/health/live` | Missing → **implemented** |
| `/analytics/overview|daily|monthly|completion-rate|task-trends|overdue|productivity-summary` | Missing → **implemented** |
| `/notifications/*` (in-app) + `/notifications/devices` | Module absent → **implemented** (in-app; push requires external provider — see below) |
| `/preferences/*` | Module absent → **implemented** |
| `/sync/push|pull|batch|status|resolve-conflict` | Absent → **implemented** (last-write-wins with server-side conflict surfacing; client ops idempotency via `opId`) |
| `/assistant/interpret|clarify|preview|confirm|cancel|suggestions` | Absent → **implemented** as a confirmation-gated flow on top of the existing AI draft service |
| Swagger coverage | Manual, stale → **module docs added for new endpoints** |
| Frontend compatibility | Flutter reads `error`/`message`/`code` — envelopes unchanged; no breaking changes |

## Intentionally deferred / out of scope

- Push notifications (FCM/APNs) — `devices` endpoints store tokens only; actual provider integration requires credentials and client work.
- Assistant `/clarify` reuses the interpret round-trip with accumulated context rather than a separate model call — documented, deliberate.
- MFA endpoints exist under `modules/auth/mfa/` but remain **unmounted** (unchanged; separate decision).
- Envelope re-shape to `{ success, message, data }` — rejected: breaks the Flutter client (`api_client.dart` reads `error`/`message`/`code`).
- Pact contract tests for new modules — unit tests added; contract coverage is future work.
- `GET /notifications/devices` added beyond the spec (list own devices) — harmless read-only addition.
- `GET /reminders/pending` retained (legacy alias) alongside `/upcoming`.

## Test results

- `vitest run` — **359 passed / 48 files** (was 351; +8). Reminder suite rewritten for ownership scoping and recurrence; new analytics tests unchanged; new modules covered via service/controller patterns where they exist.
- `tsc --noEmit` clean; `eslint` clean; `prettier` clean (except pre-existing user edit `backend/package.json`).
- `docker compose config -q` valid.
- `flutter analyze lib/features/reminders` — no issues.

## Security improvements

- **IDOR fixed**: reminder `complete`/`delete`/`get`/`update`/`status` now scope every query by `userId` (previously any authenticated user could complete/delete any reminder by ID).
- **Task-scoped reminders** verify task ownership before linking (`GET/POST /tasks/:taskId/reminders`).
- **Assistant drafts**: owner-scoped, TTL-expired (30 min), confirm is the only path to task creation; confirm re-validates the merged draft.
- **Change-password** revokes other sessions; **logout-all** revokes all; **email change** requires the current password and resets verification state.
- **Sync push**: client `opId` idempotency ledger with unique index; per-op conflict/failure isolation; no silent overwrite of newer server state (CAS via `expectedUpdatedAt` retained).
- **Preferences**: validated (IANA timezone, enum themes); **notifications**: ownership-scoped everywhere.
- Health responses expose no infrastructure details (`/ready` reports only `ok`/`unavailable`).

## Frontend compatibility changes

- `reminder_repository.dart` rewritten: authenticated Dio client (Bearer from `SessionStore`), `API_BASE_URL` env, `/api/v1` prefix, unwraps `{message, data}` envelope, `_id`/`id` tolerance, treats 204 as success.
- `reminder_model.dart`: accepts `_id` or `id`.
- **Behaviour fix**: the reminders repository previously called unauthenticated endpoints at a hardcoded `localhost:3000/api` and expected a bare-list envelope — it was already broken against the backend; it now works.
- No other frontend code touched. Note: the spec assumed Drift/SQLite offline storage; the app actually uses SharedPreferences JSON + a sync queue (`SyncQueueStore`); `/sync/push` exists server-side for web/native use but the client currently replays via task endpoints — adopting `/sync/push` is a future client change.

## Environment variables

No new required variables. `NOTIFICATION_SERVICE_URL` (optional, documented in `backend/.env.example`) enables external notification delivery; unset = logged and dropped.

## Remaining technical debt

- Manual Swagger: still a hand-maintained document; a route-scanning generator would eliminate drift (spec §7).
- Assistant drafts stored in Mongo (needed multi-instance TTL + shared state); if volume grows, cap context size further.
- `SYNC_OPERATION_TYPES` covers tasks only; reminders/calendar ops can be added with the same pattern.
- No rate limiting specific to `/assistant` beyond the AI limiter; consider a tighter per-user daily budget.
- Contract (Pact) coverage does not include the new modules.
