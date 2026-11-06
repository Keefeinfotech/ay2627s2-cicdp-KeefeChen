# Auxilia

Auxilia is an offline-first task manager with optional accounts and an AI
assistant. Tasks, XP, and achievements work without a network connection; the
backend provides authentication and the AI endpoint.

Built with Flutter, Express.js, TypeScript, MongoDB, and GitHub Actions.

## Prerequisites

- Flutter 3.47.8 (Dart 3.13 or newer)
- Node.js 22.12 or newer
- A MongoDB instance for the backend

## Features

- Create, edit, complete, and delete tasks with priority, course/subject, notes,
  and due dates; undo deletion and completion from the snackbar.
- Search titles, notes, and courses; filter status and overdue work; page through
  tasks (20 per page).
- Deadline awareness: due-today and overdue counts on the dashboard.
- XP and levels based on completed priority; achievements for milestones.
- Guest mode with local tasks; optional sign-up and sign-in for the assistant.
- A one-time onboarding introduction that persists completion locally, followed
  by separate sign-in and registration screens.
- Session restore plus an explicit splash gate at launch and named routes.
- AI assistant screen backed by the API (mock provider by default).
- Bundled Inter typography and a unified Deep Navy design system with light/dark
  themes, shared components, semantic labels, and support for 200% text scaling.

## Architecture

```
Flutter app ── local storage (shared_preferences)  -> tasks, offline-first
     │
     └── HTTPS ── Express API ── MongoDB              -> accounts
                     └────────── AI endpoint          -> assistant replies
```

- Tasks are stored on the device and are never uploaded. Guest data uses the
  owner key `local`; signed-in data uses the account email.
- Local task storage uses a versioned envelope (`auxilia.tasks.v2.*`) and
  migrates legacy v1 data on first load.
- The backend owns accounts only: signup, login, and the protected AI route.
- Sign-in tokens live in platform secure storage, not in preferences.

## Project structure

```
backend/   Express + TypeScript API (auth, AI, groups, sync, health)
frontend/  Flutter application (core design system, feature modules, local storage)
docs/      Release gates, release checklist, privacy, dependencies, reports
scripts/   Non-mutating deployment smoke checks
.github/   CI and release workflows
```

### Frontend structure

```
lib/core/        design tokens, shared widgets, API client, named-route table
lib/features/
  onboarding/     first-launch product introduction and completion store
  authentication/ login, signup, startup gate, auth/session/captcha
  home/           dashboard, task model/store/repository, editor, gamification
  assistant/      confirmation-first AI task assistant and chat API service
  groups/         group workspace, invitations and shared assignments
  sync/           durable offline queue, conflict resolution and status UI
  reminders/      in-app reminder host
  reports/        progress summaries and charts
  profile/        profile and local-data actions sheet
lib/app.dart      MaterialApp shell and theme wiring
lib/main.dart     ProviderScope entry point
```

The older `lib/screens`, `lib/widgets`, `lib/models`, `lib/services`,
`lib/routing`, `lib/theme`, and `lib/utils` paths are thin re-export shims kept
so existing imports and tests continue to work. New code should import from
`lib/core` or `lib/features` directly.

## Quick start

### Backend

```bash
cd backend
npm ci
cp .env.example .env    # Windows: Copy-Item .env.example .env
npm run dev
```

Set a `JWT_SECRET` of at least 16 characters in `.env`. The API refuses to
start without it.

- API: http://localhost:3000
- Health: http://localhost:3000/api/health
- Swagger UI (development only): http://localhost:3000/api-docs

`MONGODB_URI` must point at a reachable MongoDB instance.

### Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

`API_BASE_URL` defaults to `http://localhost:3000`. For a deployed build, pass
the public HTTPS URL. Tasks work without the backend; sign-in and the assistant
need it.

## API

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/api/health` | No | Liveness check |
| POST | `/api/auth/signup` | No | Create an account; returns `{ token, user }` (201) |
| POST | `/api/auth/login` | No | Sign in; returns `{ token, user }` |
| POST | `/api/ai/chat` | Bearer | Send `{ message }` (1-1000 chars) and receive `{ reply, provider, model }` |
| GET | `/api/sync/changes?since=<iso>` | Bearer | Pull own and assigned task changes since a cursor |
| GET | `/api/groups` | Bearer | List groups for the signed-in member |
| POST | `/api/groups` | Bearer | Create a group and become its owner |
| POST | `/api/invitations` | Bearer | Invite a member by email (owner/admin) |
| POST | `/api/invitations/accept` | Bearer | Accept an invitation token |

Errors use `{ error, code, details? }`. Validation failures return `400` with
`code: "VALIDATION_ERROR"`; protected routes return `401` without a valid token.

### Configuration

| Variable | Default | Notes |
|----------|---------|-------|
| `PORT` | `3000` | HTTP port |
| `NODE_ENV` | `development` | `production` disables Swagger UI |
| `MONGODB_URI` | - | Required to start |
| `JWT_SECRET` | - | Required, at least 16 characters |
| `JWT_EXPIRES_IN` | `1d` | Token lifetime |
| `BCRYPT_ROUNDS` | `10` | Clamped to 10-15 |
| `CORS_ORIGIN` | `http://localhost:3000,http://localhost:5173` | Comma-separated allowlist |
| `AI_PROVIDER` | `mock` | `mock` or `openai-compatible`; mock is clearly labelled and makes no external calls |
| `AI_MODEL` | `mock-model` | Mock model name; required for a real provider |
| `AI_BASE_URL` | `https://api.openai.com/v1` | OpenAI-compatible `/chat/completions` base URL |
| `AI_API_KEY` | empty | Required when `AI_PROVIDER` is not `mock` |
| `AI_MAX_TOKENS` | `400` | Clamped to 32-4096 |
| `AI_TIMEOUT_MS` | `15000` | Clamped to 1000-60000 |
| `AI_RATE_LIMIT_PER_USER` | `20` | AI requests per hour per client |
| `APP_BASE_URL` | `http://localhost:8080` | Public frontend URL used in invitation emails |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USER` / `SMTP_PASS` / `EMAIL_FROM` | empty | Enables group invitation email delivery; without SMTP, invite codes are returned for manual delivery |

Auth requests are limited to 10 per 15 minutes per client. Request bodies are
capped at 10 kb.

## Data and privacy

Tasks stay on the device. Accounts store a name (optional), email, and bcrypt
password hash. See [docs/compliance/PRIVACY.md](docs/compliance/PRIVACY.md) for the full data
inventory, deletion paths, and the AI data flow.

## Testing

```bash
cd backend
npm run typecheck
npm run test:coverage     # 188 tests, ratchet coverage thresholds enforced
npm run build

cd ../frontend
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage  # 270 tests, including accessibility checks
dart run tool/check_coverage.dart 60
flutter build web --release
```

Frontend tests cover the model, validation, XP/levels, repository schema
migration, store, task card, dashboard and profile flows, onboarding completion,
login validation and guest access, startup routing, assistant request and error
handling, session restore, undo, and 200% text-scale layouts. Platform storage is
faked in tests, so no emulator is required.

## CI/CD

`.github/workflows/ci.yml` runs on pushes to `main`, `develop`, `feature/**`,
`release/**`, and `hotfix/**`, and on pull requests to `main`, `develop`, and
`release/**`. Superseded runs are cancelled.

| Job | Checks |
|-----|--------|
| `dependency-review` | Pull requests fail on high-severity dependency changes |
| `security-scan` | Trivy filesystem scan (CRITICAL/HIGH), SARIF uploaded to code scanning (report-only) |
| `secret-scan` | High-confidence committed-secret patterns fail the build |
| `backend` | `npm ci`, production audit, typecheck, tests with coverage, build; coverage artifact |
| `frontend` | Flutter 3.47.8, `pub get`, format check, `flutter analyze`, tests with coverage, 60% line-coverage gate, web release build; coverage artifact |
| `ci-summary` | Single gate for branch protection and PR review |

Tagging `v*.*.*` runs `.github/workflows/release.yml`, which verifies tag and
package versions, reruns backend and frontend checks, packages the web build,
attests build provenance, and publishes the GitHub release. A read-only API
smoke script is available at `scripts/smoke-test.mjs`.

Backend coverage is ratcheted at 49% statements, 39% branches, 48% functions
and 50% lines; the target remains 80/60 after the excluded modules gain tests.
Frontend coverage is gated at 60% lines by `frontend/tool/check_coverage.dart`.
Full gate definitions are in
[docs/compliance/NFR_RELEASE_GATES.md](docs/compliance/NFR_RELEASE_GATES.md); use
[docs/release/RELEASE_CHECKLIST.md](docs/release/RELEASE_CHECKLIST.md) before
tagging a release.

## Accessibility

- Status is shown with text and icons, never colour alone.
- Task cards expose a summary label and a labelled completion control.
- Icon-only actions have tooltips.
- Layouts are tested at 200% text scaling on a 360 px-wide viewport.

## Limitations

- No account deletion in the app yet; contact the maintainer.
- No Google/GitHub sign-in or password reset. The backend exposes email/password
  signup and login only, so the login screen does not simulate those flows.
- Signed-in users get server-side task sync with an offline queue, conflict
  detection and manual retry; writes made while signed out stay on-device.
  OS-level background sync and scheduled OS reminders are not implemented.
- Group workspaces are implemented; the AI rubric-to-roadmap workflow is
  planned, not implemented. See [docs/planning/PROJECT_PLAN.md](docs/planning/PROJECT_PLAN.md).
- The default AI provider is a clearly labelled mock. Set
  `AI_PROVIDER=openai-compatible` with `AI_BASE_URL`, `AI_MODEL` and
  `AI_API_KEY` for a real OpenAI-compatible chat completions endpoint.
- Invitation emails require SMTP configuration; without it, invite codes are
  shown once to the inviter for manual delivery.
- Swagger UI is intentionally unavailable when `NODE_ENV=production`.

## Documentation

- [User story and CI/CD report](docs/reports/USER_STORY_CICD_REPORT.md)
- [Project plan](docs/planning/PROJECT_PLAN.md)
- [Release gates](docs/compliance/NFR_RELEASE_GATES.md)
- [Release checklist](docs/release/RELEASE_CHECKLIST.md)
- [Privacy notice](docs/compliance/PRIVACY.md)
- [Dependencies](docs/release/DEPENDENCIES.md)
- [Security policy](SECURITY.md)
