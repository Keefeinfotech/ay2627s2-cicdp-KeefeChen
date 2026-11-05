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
backend/   Express + TypeScript API (auth, AI, health, Swagger in dev)
frontend/  Flutter application (core design system, feature modules, local storage)
docs/      Release gates, release checklist, privacy, dependencies
.github/   CI workflow
```

### Frontend structure

```
lib/core/        design tokens, shared widgets, API client, named-route table
lib/features/
  onboarding/     first-launch product introduction and completion store
  authentication/ login, signup, startup gate, auth/session/captcha
  home/           dashboard, task model/store/repository, editor, gamification
  assistant/      chat screen, composer, bubbles, assistant API service
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
| POST | `/api/ai/chat` | Bearer | Send `{ message }` (1-1000 chars) and receive `{ reply }` |

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
| `AI_PROVIDER` | `mock` | Any other value returns `501` until a provider is implemented |
| `AI_MODEL` | `mock-model` | Echoed in mock responses |
| `AI_MAX_TOKENS` | `512` | Reserved for a future provider |
| `AI_API_KEY` | empty | Reserved for a future provider |
| `AI_RATE_LIMIT_PER_USER` | `20` | AI requests per hour per client |

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
npm run test:coverage     # 49 tests, coverage thresholds enforced
npm run build

cd ../frontend
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage  # 118 tests, including accessibility checks
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
| `security-scan` | Trivy filesystem scan (CRITICAL/HIGH), SARIF uploaded to code scanning (report-only) |
| `backend` | `npm ci`, typecheck, tests with coverage, build; coverage artifact |
| `frontend` | Flutter 3.47.8, `pub get`, format check, `flutter analyze`, tests with coverage, 60% line-coverage gate, web release build; coverage artifact |

Backend coverage gates: 80% statements/lines/functions, 60% branches. Frontend
coverage is gated at 60% lines by `frontend/tool/check_coverage.dart`. Full gate
definitions are in
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
- No server-side task sync; tasks are per-device and per-owner.
- Reminders are stored and validated but are not scheduled as notifications.
- Group workspaces and the AI rubric-to-roadmap workflow are planned, not
  implemented. See [docs/planning/PROJECT_PLAN.md](docs/planning/PROJECT_PLAN.md).
- The AI provider is a mock; a real provider must be implemented behind the
  existing endpoint.
- Swagger UI is intentionally unavailable when `NODE_ENV=production`.

## Documentation

- [Project plan](docs/planning/PROJECT_PLAN.md)
- [Release gates](docs/compliance/NFR_RELEASE_GATES.md)
- [Release checklist](docs/release/RELEASE_CHECKLIST.md)
- [Privacy notice](docs/compliance/PRIVACY.md)
- [Dependencies](docs/release/DEPENDENCIES.md)
- [Security policy](SECURITY.md)
