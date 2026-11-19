# Auxilia Testing Strategy

**Status:** living document. Owner: engineering. Update it whenever a test layer
is added, removed or re-gated.

This document is the single map of every testing discipline used on the
Auxilia project: what it is, where the tests live, how to run them, and which
CI gate enforces them. It covers the Flutter frontend, the Express/TypeScript
backend and the Docker-composed deployment.

## Quick start

```bash
# Everything, locally (unit + integration + frontend + DIY gates):
node scripts/run-all-tests.mjs

# Plus the full docker-compose stack and the Playwright E2E suite:
node scripts/run-all-tests.mjs --e2e

# Post-deployment smoke checks against any base URL:
node scripts/run-all-tests.mjs --smoke https://your-deploy.example.com

# Include the API performance smoke test:
node scripts/run-all-tests.mjs --perf
```

In CI these layers run on every push and pull request; see
[CI/CD gating](#cicd-gating).

## Coverage today (2026-11-19)

Measured on the QA branch the same day (`vitest list` / `flutter test`).
These numbers drift fast - update them with any PR that adds or removes a
suite. Full details: `docs/reports/REGRESSION_RUN_2026-11-19.md`.

| Layer | Suites | Result |
|---|---|---|
| Backend (vitest) | 51 files, 378 tests | all pass; coverage 59.8% statements / 50.3% branches / 61.1% functions / 60.7% lines vs the 58/48/59/58 ratchet in `vitest.config.mts` |
| MongoDB-backed (mongodb-memory-server) | `backend/tests/mongodb/` | 8 tests - real in-memory mongod: schema, pagination, CAS updates, soft-delete, ownership isolation |
| Frontend (flutter_test) | 46 files, 330 tests | all pass; line coverage 62.5% vs 62% gate (`tool/check_coverage.dart`) |
| Functional (API) | `backend/tests/functional/` | 7 tests - shared in-memory model (`tests/helpers/inMemoryTaskModel.ts`) |
| Regression (known incidents) | `backend/tests/regression/` | 5 tests (4 blocks + `it.each` expansion) |
| AI guardrails | `backend/tests/ai/` | 7 tests |
| E2E (Playwright, real stack) | `e2e/tests/` | smoke, API contract, a11y, first-run auth path; 4 browser projects |
| Performance (node + k6) | `backend/tests/performance/` | p95 budget 500 ms |
| Visual (Flutter goldens) | `frontend/test/visual/` | 2 goldens - suite restored 2026-11-19 (removed as flaky in f4e5976) |
| Contract (Pact) | `backend/tests/contract/` | consumer contract + provider verification wired into `npm test` |
| Mutation (Stryker) | `backend/stryker.config.mjs` | `tokens.ts` + `AppError.ts` - 100.00 score (26/26 killed) incl. 3 tests added to kill survivors; nightly/on-demand only, never a per-PR gate |
| Accessibility (Flutter) | `frontend/test/accessibility/` | 3 guideline tests - recreates the suite earlier doc claimed but never committed; caught 3 real WCAG AA defects in AuthShell dark mode (fixed) |
| Integration (Flutter) | `integration_test/app_test.dart` + `test_driver/` | passes on a real Android emulator (Android 17); wired into `.github/workflows/integration.yml` (weekly + manual + frontend PRs) |
| Smoke (post-deploy) | `scripts/smoke-test.mjs` | runs in `deploy-production.yml` |
| Manual | `docs/testing/MANUAL_TEST_PLAN.md` | pre-release checklist |

## The 15 testing disciplines

### 1. Unit Testing

**What:** isolated tests of single functions/classes with dependencies mocked.

- Backend — `backend/tests/unit/**` (services, middleware, validators, rate
  limiter, tokens, refresh-token utils, session cache, sync/tasks/users/groups
  modules). Run: `cd backend && npm test`.
- Frontend — `frontend/test/services`, `test/models`, `test/features/**`
  controller/use-case tests (`ParseQuickAdd`, `AnalyzeSchedule`,
  `BuildReportSnapshot`, `BuildTaskBreakdown`). Run:
  `cd frontend && flutter test`.
- CI: `backend` and `frontend` jobs.

White-box: assertions reach into implementation details freely (mocked models,
spy verification).

### 2. Integration Testing

**What:** components wired together across module boundaries.

- Backend — `backend/tests/integration/**`: HTTP → routing → validation →
  controller → service against supertest with mocked Mongoose models
  (`tests/helpers/authMocks.ts` provides the shared `queryResult`/model
  stubs).
- MongoDB-backed — `backend/tests/mongodb/tasks.mongodb.test.ts`: the real
  model + repository against an in-memory `mongod` managed by
  `mongodb-memory-server` (real schema constraints, indexes, pagination,
  CAS updates, soft-delete, ownership isolation). Runs in `npm test`.
- The in-memory Task model used by the functional suite and the Pact provider
  verification is shared as `backend/tests/helpers/inMemoryTaskModel.ts`
  (previously copy-pasted into the functional suite).
- Frontend — `frontend/test/**` widget tests pump real widget trees with
  mocked HTTP (`http/testing.dart`) and platform channels
  (shared_preferences), e.g. home dashboard, login, startup gate.

### 3. End-to-end Testing

**What:** the whole system as users experience it, no mocks.

- Stack: `docker compose up -d --build` builds MongoDB + backend + nginx
  (Flutter web). Playwright drives real browsers against it.
- Location: `e2e/tests/` — `smoke.spec.ts`, `api-blackbox.spec.ts`,
  `a11y.spec.ts`, `auth.spec.ts`.
- Browser matrix via Playwright projects: Chromium, Firefox, WebKit,
  mobile-chrome (Pixel 7). WebKit and Pixel 7 emulation cannot activate
  Flutter web's semantics tree (CanvasKit/WebKitGTK unsupported, and no
  screen reader exists on emulated devices), so the two semantics-dependent
  assertions —
  the intro→login auth flow and the WebKit engine-boot check — skip on
  those projects; every other spec runs on all four. If port 8080 is taken
  locally, remap the frontend port (this dev machine has Eclipse on 8080)
  or point `E2E_BASE_URL` elsewhere.
- Run locally:
  ```bash
  docker compose up -d --build
  cd e2e && npm ci && npx playwright install --with-deps && npm test
  docker compose down -v
  ```
- CI: `e2e` job (blocking). Uploads the Playwright HTML report as an artifact.

### 4. Manual Testing

**What:** human exploration that automation cannot do well (visual polish,
"feel", ad-hoc exploratory sessions).

- Plan and checklist: [MANUAL_TEST_PLAN.md](./MANUAL_TEST_PLAN.md).
- Used at release time (see `docs/release/RELEASE_CHECKLIST.md`) and for the
  onboarding video background and AI copy, which are judged subjectively.
- Every manual defect found must produce an automated regression test before
  closing (see [Regression Testing](#10-regression-testing)).

### 5. Automation Testing

**What:** tests executed without human intervention — in CI and locally via a
single command.

- Orchestrator: `scripts/run-all-tests.mjs` (see Quick start).
- CI: `.github/workflows/ci.yml` (every push/PR) and
  `.github/workflows/release.yml` (tags) plus the post-deploy smoke step in
  `deploy-production.yml`.

### 6. AI Testing

**What:** testing for the AI assistant (`/api/ai/*`), whose behaviour is
probabilistic in principle and guarded in practice.

Coverage in `backend/tests/ai/ai-guardrails.test.ts` and
`backend/tests/integration/ai.test.ts`:

- **Prompt-injection resilience** — hostile instructions are data, not
  commands (mock provider is an echo, so compliance is detectable).
- **Output-schema validation** — model output that fails
  `taskDraftResponseSchema` (unknown keys, bad enums) is rejected with a 502,
  never persisted or echoed.
- **Provider failure handling** — unreachable provider / non-JSON upstream
  bodies become structured 5xx AppErrors; upstream error text (which can
  contain secrets) never leaks into responses.
- **Determinism of the mock provider** — CI relies on a stable mock; a test
  pins that identical requests produce identical replies.
- **Auth & validation** — 401 unauthenticated, 400 empty message.

Provider behavior against the real OpenAI-compatible endpoint is **not**
asserted in CI (it would be flaky and costs tokens); it is exercised in
staging via the smoke suite and manually.

### 7. Functional Testing

**What:** business-rule correctness, black box from the user's perspective.

- `backend/tests/functional/` — full API journeys through the real HTTP
  pipeline against an in-memory Task store (create → list → get → update →
  delete, cross-user isolation, tag normalization, pagination, validation) and
  the full auth journey (signup → me → refresh rotation → sessions → logout →
  token rejected).
- Assertions are purely on the public HTTP contract (status, bodies, headers).

### 8. Visual Testing

**What:** pixel-level regression on stable UI surfaces.

- Flutter golden tests: `frontend/test/visual/golden_test.dart`
  (`matchesGoldenFile`), baselines in `frontend/test/visual/goldens/`.
- The suite was removed in f4e5976 as flaky and restored on 2026-11-19 with
  the flake sources designed out: all timestamps are fixed, neither task is
  overdue (no time-dependent branch), and `tester.pumpAndSettle()` drains the
  `AnimatedContainer` before capture. Goldens are generated with
  Flutter 3.47.8, the exact version pinned in CI (`ci.yml`).
- Regenerate intentionally:
  ```bash
  flutter test test/visual --update-goldens
  ```
  The PR that changes goldens must justify each changed PNG. Mismatch
  artifacts land in `test/visual/failures/` and are git-ignored.
- In CI goldens run as part of `flutter test`. Goldens are generated on the
  maintainer's platform (Windows); if the ubuntu-latest runner disagrees,
  regenerate the baselines inside the CI runner and commit those — do not
  delete the test again.
- The E2E layer deliberately does not assert screenshots (Flutter web text is
  canvas/semantics and pixel-diffing it across 3 engines is noise); goldens
  cover this instead.

### 9. Performance Testing

**What:** latency and error budgets under load.

- Backend in-process load smoke: `backend/tests/performance/load-test.ts` —
  boots the real Express app, drives fixed-concurrency traffic at the DB-free
  hot paths, reports p50/p90/p95/p99 and fails if the p95 health budget
  (default 500 ms) is exceeded or any 5xx occurs.
  ```bash
  cd backend && npm run test:performance
  # PERF_DURATION_S=30 PERF_CONCURRENCY=50 PERF_MAX_P95_MS=500
  ```
- k6 scenario for serious load/soak against staging:
  `backend/tests/performance/k6-load-test.js`.
  ```bash
  docker run --rm -i grafana/k6 run -e BASE_URL=https://staging.example.com - < backend/tests/performance/k6-load-test.js
  ```
- CI: `performance` job, **manual trigger only** (`workflow_dispatch`), kept
  out of the blocking gate because CI runners are noisy neighbours.

### 10. Regression Testing

**What:** automated tests that pin every defect ever fixed, so fixes don't
silently rot.

- `backend/tests/regression/known-issues.test.ts` — each test names its
  incident (git SHA where available):
  - `d81bd7a` / `f0d4369` — identifiers validated before Mongo queries
    (invalid `groupId` → 400, previously 500 via un-checked
    express-validator chains — see note below);
  - `4c40f63` — refresh-token replay revokes the session;
  - password policy hardening — weak/common passwords rejected;
  - rate limiting — structured 429 contract.
- Rule of thumb: **no bug closes without a regression test.** Manual findings
  included.
- The whole suite is also the regression suite for CI — every existing test
  keeps running forever unless explicitly superseded.

> **Fixed during this work:** the calendar routes registered express-validator
> chains but never enforced `validationResult(req)` — invalid input fell
> through to the repository and surfaced as a 500. `enforceValidation` was
> added in `calendar.routes.ts`; `/api/calendar` now returns 400 for malformed
> identifiers.

### 11. Compatibility Testing

**What:** the same behavior across supported platforms/browsers.

- Web browsers: Playwright projects `chromium`, `firefox`, `webkit`,
  `mobile-chrome` — all run in CI (`e2e` job).
- Flutter platforms: CI builds **web** (`flutter build web --release`); the
  Android toolchain and Windows desktop toolchains are installed locally and
  verified by `flutter analyze`/`flutter test` cross-platform code paths. A
  device-farm matrix is future work (see gaps).
- Nginx serving and CSP behavior are verified per PR by the E2E smoke suite
  (`content-security-policy` header asserted).

### 12. Accessibility Testing

**What:** machine-checkable WCAG 2.x conformance for the UI.

- Flutter: semantic assertions at the widget level — e.g.
  `test/widgets/task_card_test.dart` asserts the semantics label and the
  checkbox toggle label with `tester.ensureSemantics()`.
- Flutter: WCAG guideline suite `test/accessibility/accessibility_test.dart`
  — `textContrastGuideline`, `androidTapTargetGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline` against
  `TaskCard (light)`, `LoginScreen (light)` and `LoginScreen (dark)`.
  Recreated 2026-11-19; it immediately caught 3 real WCAG AA failures in
  AuthShell dark mode (the form card was hardcoded white under dark-theme
  near-white text, ~2.5:1) — fixed in the same PR.
- Web: `e2e/tests/a11y.spec.ts` - axe-core scan; critical violations fail,
  serious are reported.
- Manual pass for screen-reader flows: see MANUAL_TEST_PLAN.md
  (VoiceOver/TalkBack items).

### 13. Smoke Testing & Sanity Testing

**What:** the cheapest, fastest signal that something is catastrophically
broken.

- **Smoke** (post-deploy, read-only): `scripts/smoke-test.mjs` — health → 200,
  unauthenticated AI chat → 401, unknown route → 404. Wired into
  `deploy-production.yml`.
- **E2E smoke** (pre-merge): `e2e/tests/smoke.spec.ts` additionally checks the
  SPA boots, CSP is strict, and client-side routes fall back to `index.html`.
- **Sanity** (build verification): the CI pipeline itself — `npm run build` /
  `flutter build web` + the full test gates — is the sanity check that a
  change is basically sound before deeper review.
- **API soak**: `k6-load-test.js` can run as a scheduled soak in staging.

### 14. White Box & Black Box Testing

**What:** two complementary perspectives.

| Perspective | Means | Where it lives |
|---|---|---|
| White box | knows internals (code paths, models, mocks) | `backend/tests/unit/**`, `tests/ai/` (provider mocking), `sync`/`task` service tests with mocked repos |
| Grey box | HTTP surface + mocked persistence | `backend/tests/integration/**`, `tests/security/` |
| Black box | public contract only, zero internals knowledge | `backend/tests/functional/**`, `scripts/smoke-test.mjs`, `e2e/tests/api-blackbox.spec.ts`, `e2e/tests/smoke.spec.ts` |

Both are required: white box proves we did it right; black box proves it works.

### 15. Testing for Different AUTs (Applications Under Test)

Different applications need different tools. Auxilia has four:

| AUT | Toolchain | Test layers |
|---|---|---|
| Backend API (Express) | vitest + supertest + Pact | unit, integration, functional, regression, security, AI, performance |
| Flutter web (browser AUT) | flutter_test + Playwright | widget/service tests, golden (visual), a11y, E2E |
| Flutter Android/iOS/Windows (app AUT) | flutter_test + integration_test | unit/widget tests on device; `frontend/integration_test/app_test.dart` drives the real app; **runs in CI** (`integration.yml`, Android emulator, weekly + manual + on frontend PRs); verified locally on a real Android 17 emulator |
| Docker-compose deployment (stack AUT) | docker compose + Playwright + smoke script | E2E smoke, a11y, black-box API, post-deploy smoke |

To run the Flutter AUT on a device/emulator:

```bash
cd frontend
flutter test integration_test/app_test.dart        # where supported
# or
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart
```

## CI/CD gating

| Job | Suites enforced | Blocking |
|---|---|---|
| `backend` | lint, typecheck, `npm test` (unit+integration+contract+security+functional+regression+ai), build, coverage ratchet 58/48/59/58 | yes |
| `frontend` | format, analyze, `flutter test` (incl. goldens), 62% line gate, web build | yes |
| `e2e` | docker-compose stack health, Playwright smoke/API/a11y/auth (4 browser projects) | yes |
| `dependency-review` | dependency graph diff scan, fails on high severity | yes (PR only) since the repo is public — enabled 2026-11-19 via repo variable `DEPENDENCY_REVIEW_ENABLED=true`; was previously off because the repo was private without GitHub Advanced Security |
| `integration.yml` | Flutter `integration_test` on an Android emulator (API 34) | no — advisory by design (weekly + `workflow_dispatch` + frontend PRs); not wired into `CI - Final Quality Gate` |
| `mutation.yml` | Stryker mutation testing, scoped to `tokens.ts` + `AppError.ts` | no — advisory (nightly + `workflow_dispatch`); never a per-PR gate |
| `performance` | node load smoke (p95 budget) | manual only (`workflow_dispatch`) |
| `ci-summary` | aggregates all gates (E2E included) | branch protection (`CI - Final Quality Gate`) |
| `deploy-production.yml` | post-deploy `smoke-test.mjs` | deployment |

Contract testing runs inside the `backend` job (`tests/contract/`): the Pact
consumer test generates `pacts/Auxilia-Frontend-Auxilia-API.json` and
`tasks.provider.test.ts` verifies it against the real Express app (in-memory
Task store, ephemeral port). Both must stay green together — a contract edit
in one without the other is an automatic CI failure.

## Ratcheting and maintenance

- Frontend 62% line gate and backend 58/48/59/58 thresholds must not be
  lowered (ADR required). Raise them as coverage improves - the backend
  gate is green today (59.8/50.3/61.1/60.7); feature branches that add
  modules without tests will turn it red, and the fix is tests, not a
  lower ratchet.
- Goldens regenerate only via `flutter test test/visual --update-goldens`
  with a justification in the PR.
- New features: unit + integration tests mandatory; user-facing flows get a
  functional or E2E test; fixed defects get a regression test.
- GitHub Advanced Security is not needed for Dependency Review now that the
  repository is public; `Dependency Review` is a required-by-convention PR
  gate (enforced via `CI - Final Quality Gate`).
- `docs/planning/TASKS.md` is the product backlog; this file is the testing backlog index.

## Known gaps and future work

1. **Seed-script idempotency tests** (open item in `docs/planning/TASKS.md`) - `seed.ts`
   would be an ideal first tenant of `mongodb-memory-server` (the harness
   now exists — see `tests/mongodb/`).
2. ~~**Pact provider verification**~~ — **done (2026-11-19).** Runs in
   `npm test`; consumer contract now describes the actual provider.
3. **Device-farm / iOS integration coverage** — Android emulator runs in
   `.github/workflows/integration.yml`; iOS needs macOS runners (free for
   public repos) — extend the same workflow with an `ios` job.
4. **Staging soak with SLO alerting** — the SLO burn-rate rules now exist
   (`monitoring/prometheus-slo.yml`) and the error-budget policy is defined
   (`docs/operations/MONITORING_RUNBOOK.md`); what does not exist is a
   *scheduled* soak driving the SLI metrics (k6, `workflow_dispatch` today).
5. **Coverage must stay green on new modules** — any feature branch adding
   modules without tests turns the ratchet red. No exceptions: new code
   lands with tests.
6. ~~**Flutter accessibility guideline suite**~~ — **done (2026-11-19).**
   `test/accessibility/` recreates the suite; it caught 3 real WCAG AA
   defects (AuthShell dark mode) on first run.
7. ~~**MongoDB-backed integration tests**~~ — **done (2026-11-19) for the
   tasks module** (`tests/mongodb/`). Every other module's model behaviour
   is still mocked above the E2E layer; extend coverage module by module.
8. **Stryker scope is deliberately tiny** — `tokens.ts` + `AppError.ts`
   only, 100.00 score as of 2026-11-19. Expand to other critical modules
   (auth service, task service) with the ADR route; never into the
   per-PR gate.

## Monitoring and alerting (outside the test suite, tracked here)

- Prometheus loads `monitoring/prometheus-alerts.yml` (severity tickets) and
  `monitoring/prometheus-slo.yml` (error-budget burn-rate rules) via
  `rule_files`, backed by an example Alertmanager
  (`monitoring/alertmanager.yml`, local inert default;
  `monitoring/alertmanager.slack.example.yml` for Slack delivery) wired into
  the `monitoring` compose profile (`docker compose --profile monitoring up
  -d`).
- **Runbook + SLO definitions:** [`docs/operations/MONITORING_RUNBOOK.md`](../operations/MONITORING_RUNBOOK.md)
  — availability 99.5% / latency 99.0% over 28 days, error-budget policy,
  alert→action map, Grafana/Prometheus access.
- Alert delivery is a placeholder in the local profile; a real receiver must
  be wired before production use (slack example is committed and ready).
  There is still no external uptime prober — if the process is dead, the
  SLI measures nothing (that is what `BackendDown` is for).
