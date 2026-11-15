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

## Coverage today (2026-11-12)

| Layer | Suites | Result |
|---|---|---|
| Backend (vitest) | 44 files, 340 tests | all pass; coverage ratcheted at 49/39/48/50 |
| Frontend (flutter_test) | 47 files, 320 tests | all pass; ≥ 60% lines gated |
| Functional (API, in-memory model) | `backend/tests/functional/` | 7 tests |
| Regression (known incidents) | `backend/tests/regression/` | 7 tests |
| AI guardrails | `backend/tests/ai/` | 11 tests |
| E2E (Playwright, real stack) | `e2e/tests/` | smoke, API contract, a11y, first-run auth path; 4 browser projects |
| Performance (node + k6) | `backend/tests/performance/` | p95 budget 500 ms |
| Accessibility (guideline tests) | `frontend/test/accessibility/` | 3 tests |
| Visual (Flutter goldens) | `frontend/test/visual/` | 2 goldens |
| Contract (Pact) | `backend/tests/contract/` | consumer contract for `/api/tasks` |
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
- Regenerate intentionally:
  ```bash
  flutter test test/visual --update-goldens
  ```
  The PR that changes goldens must justify each changed PNG.
- In CI goldens run as part of `flutter test`. Note: goldens are generated on
  the maintainer's platform (Windows); a font-rendering difference elsewhere
  may require regenerating baselines in a consistent environment (CI:
  ubuntu-latest). This is a known limitation — if CI goldens flake, regenerate
  the baselines inside the CI runner and commit those.
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

- Flutter guideline tests: `frontend/test/accessibility/accessibility_test.dart`
  — `textContrastGuideline`, `androidTapTargetGuideline`,
  `iOSTapTargetGuideline`, `labeledTapTargetGuideline` on TaskCard (light),
  LoginScreen (light and dark).
- Web: `e2e/tests/a11y.spec.ts` — axe-core scan; critical violations fail,
  serious are reported.
- Manual pass for screen-reader flows: see MANUAL_TEST_PLAN.md
  (VoiceOver/TalkBack items).
- Two real defects were fixed to make these green: secondary text contrast
  (#7B7F8A → #5A5F6A), link/accent steel blue (#6B7C98 → #4F5D75), light
  primary button text (near-black → white), auth screens' hard-coded light
  background in dark mode, and TaskCard 40px icon buttons → 48px.

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
| Flutter Android/iOS/Windows (app AUT) | flutter_test + integration_test | unit/widget tests on device; `frontend/integration_test/app_test.dart` drives the real app on a device/emulator; CI coverage on web |
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
| `backend` | lint, typecheck, `npm test` (unit+integration+contract+security+functional+regression+ai), build, coverage | yes |
| `frontend` | format, analyze, `flutter test` (incl. goldens + a11y), 60% line gate, web build | yes |
| `e2e` | docker-compose stack health, Playwright smoke/API/a11y/auth (4 browser projects) | yes |
| `performance` | node load smoke (p95 budget) | manual only (`workflow_dispatch`) |
| `ci-summary` | aggregates all gates (E2E included) | branch protection |
| `deploy-production.yml` | post-deploy `smoke-test.mjs` | deployment |

## Ratcheting and maintenance

- Frontend 60% line gate and backend 49/39/48/50 thresholds must not be
  lowered (ADR required). Raise them as coverage improves.
- Goldens regenerate only via `flutter test test/visual --update-goldens`
  with a justification in the PR.
- New features: unit + integration tests mandatory; user-facing flows get a
  functional or E2E test; fixed defects get a regression test.
- `docs/planning/TASKS.md` is the product backlog; this file is the testing backlog index.

## Known gaps and future work

1. **Seed-script idempotency tests** (open item in `docs/planning/TASKS.md`) — `seed.ts`
   needs a real or embedded MongoDB; the intended approach is a focused unit
   test around its find-or-create helpers, or running it twice against a
   scratch database in CI.
2. **Pact provider verification** — contract exists on the consumer side; the
   API should verify `pacts/Auxilia-Frontend-Auxilia-API.json` in CI.
3. **Device-farm matrix for Android/iOS** — integration_test on emulators in
   `integration.yml` (macOS runners for iOS).
4. **Staging soak** — scheduled k6 run with SLO alerting.
5. **Visual diff across engines** — Playwright `toHaveScreenshot` behind a
   dedicated, advisory-only job.
