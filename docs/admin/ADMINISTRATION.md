# Auxilia Administrative Module

**Audience:** developers, reviewers, markers, and demo operators.
**Status:** implemented; demo seed verified locally; Grafana validated locally via Docker.

This document describes the administrative module: architecture, RBAC, the
administrative API, analytics calculations, monitoring architecture, testing
evidence, known limitations and future enhancements.

---

## 1. What the module does

| Capability | Implementation |
|---|---|
| Administrator role and authorisation | Existing `USER_ROLES`/`authenticate` + hardened `authorize` middleware |
| Registered user management | `GET /api/admin/users`, `PATCH /api/admin/users/:id/status` |
| Aggregated platform statistics | `GET /api/admin/stats` |
| Administrative UI (Flutter) | `frontend/lib/features/admin/` — dashboard, user management, analytics charts |
| Backend observability | `modules/metrics/metrics.ts`, `/metrics`, Prometheus + Grafana compose profile |
| Demo data | `backend/scripts/seed-admin-demo.ts` (`npm run seed:demo`) |

**Guiding rule:** administrative users can see *aggregate platform metrics* and
*account metadata* (name, email, status, registration date, last login). They
cannot read any user's tasks, notes, reminders, or message contents through
these endpoints. The dashboard intentionally has no "view user tasks" action.

---

## 2. Architecture

```
Flutter (admin UI)                      Express backend
┌─────────────────────────┐            ┌────────────────────────────────┐
│ features/admin/         │  HTTPS     │ modules/admin/                  │
│  data/admin_repository  │ ─────────▶ │  admin.routes  → authenticate → │
│  data/models            │  Bearer    │                  authorize("admin")
│  presentation/...pages  │            │  admin.controller               │
│ core/routing/app_router │            │  admin.service (business rules) │
│ core/layout/app_shell   │            │  admin.repository (Mongoose)    │
└─────────────────────────┘            │ modules/users/user.schema.js    │
                                       │  (single User schema — see 2.2) │
                                       │ modules/metrics/metrics.ts      │
                                       │  /metrics (guarded)             │
                                       └────────────────────────────────┘
```

### 2.2 One User schema, not two (required reading for operators)

The repository previously registered the same `User` model twice — once in
`users/user.model.js` and once in `auth/auth.model.js` — with **different
`_id` types** (String UUID vs. default ObjectId) and different field sets.
Whichever schema registered first per process won, silently altering
validation behaviour:

* logins worked for sign-up-created users (ObjectId ids),
* seeded demo users (UUID ids) logged in but **failed validation on save**
  and every interesting auth write threw a `ValidationError` surfaced as
  `{"error":"Validation failed","code":"VALIDATION_ERROR"}`.

Fix shipped here: `modules/users/user.schema.js` defines the union once and
both model files are now thin wrappers over it. Registration order no longer
matters. The union keeps `_id` as String UUID — the type every other
collection already uses (tasks, groups, sessions, sessions.userId, ...).

**Production data note:** any pre-existing user documents with an ObjectId
`_id` must be migrated to string ids *before* this code is deployed, or
their full-document saves will fail validation after the change. The
guarded migration is included:

```bash
cd backend
MONGODB_URI=... npm run migrate:user-ids            # dry run, prints a plan
MONGODB_URI=... npm run migrate:user-ids -- --apply # applies, keeps a backup
```

It backs up every migrated document into
`users_backup_pre_string_ids`, rewrites `_id` to the string form in place,
is idempotent (only ObjectId-typed `_id`s are touched), and in production
refuses to apply unless `ALLOW_USER_ID_MIGRATION=true` is set explicitly.
References (`sessions.userId`, `tasks.userId`, etc.) were always stored as
`String(user._id)` and need no changes.

### 2.1 RBAC design

* Roles live in `backend/src/constants/security.ts`: `USER_ROLES = ["user", "admin"]`.
* `authenticate` middleware verifies the access token (`sub`, `jti`, issuer,
  HS256) and loads the session + user from MongoDB; `req.userRole` comes from
  the **database**, never from the request.
* `authorize(...roles)` (`src/middleware/authorize.ts`) compares roles
  **case-insensitively**. Before this change the middleware compared against
  upper-case `"ADMIN"` while the database stores `"admin"`, which made the
  existing `/api/feedback/analytics/*` endpoints unreachable for real admins.
  The normalisation fixes that defect as a side effect.
* Client-side role display (`Session.isAdmin`) is **UI gating only**. Hiding a
  tab is not a security boundary — every admin endpoint re-checks the role
  server-side. A standard user who flips a client-side flag gets 403 from the
  API.
* Administrator privileges cannot be granted through the client: there is no
  sign-up path to `admin` (role is set server-side; the seed creates the admin
  account), and `role` is never accepted from a request body.

### 2.2 What administrators cannot do

* Deactivate their own account (`SELF_DEACTIVATION`).
* Deactivate the last active administrator (`LAST_ADMIN`).
* Read `passwordHash`, MFA secrets, refresh tokens, or session identifiers —
  none of these are projected by the admin repository (`SAFE_USER_FIELDS`).
* See task *contents* or notes — the statistics endpoint aggregates counts only.

---

## 3. Administrative API

Base path: `/api/admin`. All routes require a valid session with role `admin`
(403 otherwise, 401 without a session).

### 3.1 `GET /api/admin/users`

Query parameters (all optional): `page` (int ≥ 1, default 1),
`limit` (int 1–100, default 20), `search` (≤ 120 chars, name/email, regex-escaped),
`status` (`active` | `disabled` | `pending`).

Response `200`:

```json
{
  "message": "Users retrieved successfully.",
  "data": {
    "items": [
      {
        "id": "...", "name": "...", "email": "...",
        "role": "user", "status": "active",
        "createdAt": "2026-10-01T00:00:00.000Z",
        "lastLoginAt": "2026-11-10T08:00:00.000Z"
      }
    ],
    "total": 42, "page": 1, "limit": 20, "totalPages": 3
  }
}
```

### 3.2 `PATCH /api/admin/users/:id/status`

Body: `{ "status": "active" | "disabled" }`.

* `400` — invalid body (`INVALID_BODY`), self-deactivation (`SELF_DEACTIVATION`).
* `404` — unknown user (`NOT_FOUND`).
* `409` — target is the last active administrator (`LAST_ADMIN`).
* `200` — updated account projected with safe fields.

### 3.3 `GET /api/admin/stats`

Response `200` (shape modelled in `admin.types.ts`):

```json
{
  "users": { "total": 42, "active": 30, "disabled": 10, "pending": 2, "newLast7Days": 5 },
  "tasks": {
    "total": 130, "todo": 40, "inProgress": 20, "completed": 60,
    "archived": 10, "completionRate": 0.5,
    "createdLast7Days": 12, "completedLast7Days": 9
  },
  "taskCreationTrend": [{ "date": "2026-11-01", "count": 3 }, "... 14 points"],
  "taskCompletionTrend": [{ "date": "2026-11-01", "count": 2 }, "... 14 points"]
}
```

### 3.4 Analytics calculations

* `users.total = active + disabled + pending` (the three stored statuses).
* `tasks.total = todo + in_progress + completed + archived`, excluding
  soft-deleted documents (`deletedAt: null`).
* `completionRate = completed / (total − archived)` (0 when no active tasks).
  Archived work is excluded because it represents discarded, not completed, work.
* Trends are **UTC daily buckets over the trailing 14 days** via a
  `$dateToString` aggregation. Days with no activity appear as `count: 0`
  (filled in server-side after aggregation).
* `createdLast7Days`/`completedLast7Days` use rolling 7 × 24 h windows.

### 3.5 Rate limiting / caching

All admin routes sit behind the global `/api` API rate limiter and the
"no-store"-adjacent auth posture already used by `/api/auth`. Statistics are
computed on demand from MongoDB; there is no stale cache to invalidate.

---

## 4. Flutter admin module

Location: `frontend/lib/features/admin/`.

* `data/models.dart` — typed models mirroring the wire format
  (`AdminStats`, `AdminUserSummary`, `AdminUsersPageData`, …).
* `data/admin_repository.dart` — `AdminRepository` over the existing
  `ApiClient` (adds nothing new to the network layer). `AdminException`
  surfaces safe messages with `statusCode`.
* `presentation/pages/admin_dashboard_page.dart` — overview stat cards,
  14-day creation/completion bar chart (`fl_chart`), account-status summary,
  user-management entry point, system-monitoring section.
* `presentation/pages/admin_users_page.dart` — debounced search, status
  filter chips, pagination, activate/deactivate per row (admin accounts shown
  read-only to avoid last-admin footguns; the server enforces it too).
* Navigation: desktop sidebar/tablet rail get an **Admin** destination,
  visible only when `session.isAdmin`; the mobile bottom bar is unchanged.
  Deep links to `/admin` without an admin session render a placeholder
  instead of the console.
* Routing stays on the existing `AppRouter`/`MaterialPageRoute` table
  (`AppRoutes.admin`, `AdminArgs`) — no new routing framework introduced.

**Deliberate deviations from the original brief (documented, not silent):**

* Roboto → kept **Inter**, the app's committed typeface, to remain consistent
  with the existing design system (the brief's own priority #9: "maintain
  consistency with the existing application design").
* Lucide icons → kept **Material Icons** (no icon-font dependency exists and
  adding one is not justified for this scope).
* `fl_chart` was added (single new dependency) for real, live charts.

---

## 5. Monitoring with Prometheus and Grafana

### 5.1 What is measured (and what is not)

| Metric | Source | Notes |
|---|---|---|
| `auxilia_http_requests_total` | counter middleware | method, normalised route, status code |
| `auxilia_http_request_duration_seconds` | histogram middleware | p50/p95/p99 via histogram_quantile |
| `process_*` / node defaults | `prom-client` default metrics | CPU, RSS, GC, event-loop lag |
| `auxilia_db_connected` | gauge set at each scrape | 1 when mongoose readyState == connected |
| Backend availability | Prometheus `up{}` | synthetic liveness of the target |

Route labels are normalised (`/api/tasks/:uuid`) to bound cardinality; query
strings are stripped. **No per-user labels, no task content, no request bodies.**

### 5.2 `/metrics` endpoint security

`/metrics` is not public:

1. If `METRICS_TOKEN` is set, requests must carry
   `Authorization: Bearer <METRICS_TOKEN>` (compared with a timing-safe
   equality check). Prometheus is configured with the same token
   (`monitoring/prometheus.yml`, local-demo default `auxilia-local-metrics-token`).
2. If `METRICS_TOKEN` is unset, the endpoint falls back to requiring an
   authenticated **administrator** session.

The token never enters git for real deployments — only the local-demo default
value is committed, and it is labelled as such in the compose file and docs.

### 5.3 Running the stack (local demo)

```bash
docker compose --profile monitoring up -d
# Prometheus: http://localhost:9090   (Status → Targets shows auxilia-backend UP)
# Grafana:    http://localhost:3001   (admin / admin — change GRAFANA_ADMIN_PASSWORD)
```

The Grafana datasource and the **Auxilia Backend** dashboard
(`monitoring/grafana/dashboards/auxilia-backend.json`) are provisioned
automatically: backend up, MongoDB connected, request rate by route, p95
latency by route, 5xx error fraction, RSS and CPU.

### 5.4 Render limitation (honest scope note)

The Render free tier runs a single Docker web service. It cannot host
Prometheus/Grafana, and Prometheus cannot reach services that only Render
controls without a scrape endpoint that the free service exposes — which
`/metrics` now does, but only reachable from inside the same Render private
network/public internet if the firewall allows it, and with a secret that must
be set in the dashboard. **The supported, verifiable monitoring demo is
therefore the local Docker stack above.** On Render, the workflow's health
gate (`/api/health`) remains the availability signal, and the Grafana stack is
reserved for local development and demonstration.

---

## 6. Demo environment

### 6.1 Seed script

`backend/scripts/seed-admin-demo.ts` — creates demo users, an administrator
and task data with a 30-day activity spread. Usage:

```bash
cd backend
MONGODB_URI=mongodb://localhost:27017/auxilia npm run seed:demo
```

Guards: refuses to run with `NODE_ENV=production` unless `ALLOW_DEMO_SEED=true`.
Idempotent: existing accounts (by email) and users who already own tasks are
skipped, so the script can be re-run safely. Passwords are always bcrypt-hashed
with the application's `BCRYPT_ROUNDS`.

### 6.2 Demo accounts

| Role | Email | Password |
|---|---|---|
| Administrator | `admin@auxilia.demo` | `AdminDemo!2026` |
| Standard user | `grace@auxilia.demo` | `DemoUser!2026` |
| Standard user | `liam@auxilia.demo` | `DemoUser!2026` |
| Standard user | `priya@auxilia.demo` | `DemoUser!2026` |
| Standard user | `wei@auxilia.demo` | `DemoUser!2026` |
| Standard user | `fatimah@auxilia.demo` | `DemoUser!2026` |
| Standard user | `daniel@auxilia.demo` | `DemoUser!2026` (disabled) |
| Standard user | `meera@auxilia.demo` | `DemoUser!2026` (pending) |

These accounts exist only for development/demo. The seed script is the only
supported way to create them.

### 6.3 Seed scope and known data limitations

* Tasks are seeded with statuses `todo`, `in_progress`, `completed` and a
  trailing 30-day creation spread; completed tasks carry `completedAt`,
  roughly half a day after creation — enough to drive non-empty charts.
* **Reminders and calendar events are NOT seeded.** Both models reference the
  user by `Schema.Types.ObjectId`, while the application identifies users by
  string UUID — a separate pre-existing schema inconsistency (tracked as
  future work below), not something the seed script works around by
  inventing data.
* `lastLoginAt` is populated for the accounts that demonstrate it; accounts
  created after the field shipped may show `—` (no login recorded yet).

---

## 7. Testing evidence

| Layer | What was run | Result |
|---|---|---|
| Backend unit | `authorization.test.ts` (RBAC incl. case-insensitivity) | pass |
| Backend integration | `admin.test.ts` — 401/403 RBAC, list validation, deactivation guards, stats aggregation, error handling, `/metrics` guards | pass |
| Backend full suite | `npm test` (40 files) | **314/314 pass** |
| Backend build | `tsc --noEmit` | pass |
| Backend format gate | `npm run format:check` | pass |
| Frontend unit/widget | `test/features/admin/*` (repository over mock HTTP, dashboard render + error path) | **7/7 pass** |
| Frontend full suite | `flutter test` | **315/315 pass** |
| Flutter analyze | `flutter analyze --no-fatal-infos` | 0 errors, 0 warnings from new code |
| Flutter format | `dart format --set-exit-if-changed` | pass |

Backend admin tests mock the Mongoose models (repository layer) and exercise
the real Express pipeline with supertest — consistent with the existing
integration-test convention (`tests/integration/auth.test.ts`). Two existing
assertions changed because the public auth payload now includes `role`
(required for admin-UI gating): `auth.test.ts` sign-up deep-equal and
`session.test.ts` `/api/auth/me` property check.

### 7.1 End-to-end verification (local Docker)

Run against `mongo:7` in Docker with the backend started via `tsx` on a free
port, seeded by `npm run seed:demo`:

| Check | Result |
|---|---|
| Seed creates admin + 7 users + 70 tasks idempotently | pass |
| Admin login → `user.role` is `admin` in the response | pass |
| `GET /api/admin/stats` with admin JWT | 200; real aggregates (9 users, 70 tasks, 28 completed) |
| `GET /api/admin/users?status=active` | safe fields only, no `passwordHash` |
| Standard user hits `/api/admin/stats` and `/api/admin/users` | 403 both |
| Admin deactivates Grace; raw Mongo read-back | `status: "disabled"` persisted; re-activated to `active` |
| `/metrics` without token (when `METRICS_TOKEN` set) | 401 |
| `/metrics` with `Bearer local-e2e-metrics-token` | 200; `auxilia_db_connected 1`, counters reflect the 200/403 traffic above |
| Migration script dry-run on a hand-created legacy ObjectId user | reports 1 candidate, no writes |
| Migration `--apply` | document moved to `users_backup_pre_string_ids`, `_id` stringified; legacy user login succeeds afterwards |
| Web release build (`flutter build web --release`) | pass; bundle contains admin routes |

---

## 8. Known limitations

1. Grafana/Prometheus are validated **locally** (Docker). Render free tier
   cannot host them; production monitoring would need a managed Prometheus or
   the provisioned datasource pointed at a reachable `/metrics` endpoint with
   a secret token.
2. `/metrics` cannot be reachable anonymously by design; the local demo token
   must not be reused outside local development.
3. `lastLoginAt` is only available for sign-ins that occurred after the field
   was introduced; older accounts show no last-login value rather than a
   fabricated one.
4. Trend series are UTC-based. Multi-timezone grouping was deliberately out of
   scope.
5. Reminders/calendar demo data is unavailable until the ObjectId/string user
   identifier inconsistency is resolved (see future work).
6. The admin UI does not paginate the "Recently registered users" widget
   beyond `limit=5`; the full console is on the user-management screen.
7. Refresh tokens and MFA remain enforced as before; the admin console does
   not surface session internals.

## 9. Future enhancements

* Unify reminders/calendar `userId` field types with the rest of the app
  (currently `ObjectId` vs the app-wide string UUID) — fixes reminder/calendar
  demo seeding and simplifies joins.
* Audit log of administrative actions (deactivation events) with the existing
  audit module.
* A blackbox Prometheus probe against `/api/health` for an availability SLO.
* Per-service alerting rules (error-rate and p95 thresholds) with Alertmanager.
* Predictive task-completion analytics — explicitly out of scope for v1.

## 10. Future production checklist

* **Run `npm run migrate:user-ids` before deploying** if any production user
  documents still carry ObjectId `_id`s (created before the schema union);
  verify logins afterwards and drop `users_backup_pre_string_ids` once the
  rollback window is closed.
* Set `METRICS_TOKEN` (random 32+ bytes) in Render/GitHub secrets; update
  `monitoring/prometheus.yml` or, better, a private scrape config.
* Do **not** create the demo accounts in production. The seed refuses without
  `ALLOW_DEMO_SEED=true`, and the demo passwords are public by design.
* Confirm `admin` role assignment is done by direct DB intervention only
  (e.g. `db.users.updateOne({ email }, { $set: { role: "admin" } })`).
