# Auxilia v1.0.0 — Release Notes

Date: 12 November 2026
Release branch: `release/v1.0.0` (fast-forwarded to `main` at `d54c916`)
Tag: `v1.0.0` (to be created after NP-16 sign-off)

## What ships in v1.0.0

This is the first public release of Auxilia: an offline-first Flutter student
task manager (mobile + web) backed by an Express/Mongoose API, with a full
enterprise-grade delivery pipeline.

### Delivered (Jira Done)

| Key | Story | Evidence |
|---|---|---|
| NP-6 | Set up Flutter project and Git repository | Flutter 3.47.8 project, pinned CI, Git history |
| NP-7 | Establish app navigation and layout | `app_shell`, responsive bottom rail/sidebar, navigation tests |
| NP-8 | Create and view tasks | `task_management_page`, backend `task.routes.ts` |
| NP-9 | Edit, delete, and complete tasks | `task_card`, `task_editor`, PATCH/DELETE endpoints |
| NP-10 | Persist tasks using local storage | `sync_queue_store`, offline-first `api_task_repository` |
| NP-11 | Build student task dashboard | `home_screen`, gamification, achievements |
| NP-12 | Customizable avatar | `app_avatar.dart`, `avatar_store.dart` |
| NP-13 | Display task priorities and deadlines | priority/due UI + backend validation |
| NP-14 | Implement task reminders | `features/reminders/`, in-app `ReminderHost` |
| NP-18 | Set up Flutter and Dart project environment | CI setup-flutter pinned to 3.47.8 |

### Implemented but In Progress (release blockers)

| Key | Story | Status |
|---|---|---|
| NP-15 | Display task progress summaries | Implemented; CI green, Jira evidence pending |
| NP-19 | Interact with AI assistant through text | Implemented; live provider needs credentials, Jira evidence pending |
| NP-16 | Test critical workflows and prepare release | Release gates exist; this release + checklist evidence pending |

### Known boundaries (not in v1.0.0)

- OS-level notifications (reminders fire in-app while the app is running)
- Full offline conflict resolution beyond the sync-centre UI
- Epics NP-1 – NP-5 and NP-17 (Foundation, Core Tasks, Dashboard,
  Reminders/Insights, Testing & Release, AI Personal Assistant): children
  above are shipped; the epics themselves close when their children do.

## Quality gates evidence

- Backend: prettier/ESLint/tsc, 212 tests green, coverage ratcheted,
  `npm audit` clean, Docker image Trivy-clean (non-root, pinned digest base)
- Frontend: format/analyzer, **277 tests** green, ≥60% line coverage, web
  build (`flutter build web --release`) clean
- CI: single required check `CI - Final Quality Gate` aggregates everything;
  SonarCloud quality gate passing; CodeQL passing
- Concurrency: compare-and-swap `expectedUpdatedAt` on task updates; atomic
  conditional writes; conflict surfacing instead of last-write-wins
- Pagination: full-snapshot client-side pagination over server-side offset
  pagination capped at 100/page
- DB: `$jsonSchema` validators for all 14 collections
  (`npm run validate:collections`)
- Deploy: backend on Render (`render.yaml`, `/api/health` gate + smoke test),
  web artifact attached to the tag release with build provenance attestation

## Rollout and rollback

- Rollout: merge to `main` → Render backend deploys with `/api/health` wait +
  smoke checks; tag `v1.0.0` → release workflow builds & attests the web
  artifact.
- Rollback: `git revert` the release commit on `main` and redeploy; Render
  keeps the previous deploy for one-click rollback.

## Manual gates required before v1.0.0 is public

1. NP-16 sign-off: smoke-test against the deployed API
   (`node scripts/smoke-test.mjs <api-host>`)
2. Manual checks: signup/login, task CRUD, offline task, screen reader,
   200% text scale
3. Confirm Render env vars are set (`MONGODB_URI`, `JWT_SECRET`, `CORS_ORIGIN`,
   `TURNSTILE_*`, `RENDER_API_BASE_URL`, optional `RENDER_DEPLOY_HOOK_URL`)
4. Flip NP-15, NP-16, NP-19 to Done; close epics as children complete
5. Push tag `v1.0.0` (triggers release workflow; builds & attests web artifact)
