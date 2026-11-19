# Auxilia — Testing Tools Report

**Date:** 19 November 2026 · **Branch:** `feature/qa-contract-goldens-monitoring` (PR → `main`) · **Assessor context:** CA1 self-evidence (AY26/27 ST0529)
**Pairs with:** [../testing/TESTING_STRATEGY.md](../testing/TESTING_STRATEGY.md) (the living map of how to run and gate the suites) · [./RUBRIC_SELF_ASSESSMENT.md](./RUBRIC_SELF_ASSESSMENT.md)

This report answers the question *"what testing tools did you use?"* honestly:
what each tool is, where it lives in the repo, why it was chosen, and what it
is currently worth — including where it is missing or failing. Counts below
were measured on 2026-11-19 (`vitest list`, `flutter test`) against `main`
with this PR applied, not copied from earlier documents.

---

## 1. Executive summary

| Layer | Tool | Where | Status on this branch |
|---|---|---|---|
| Backend unit/integration/functional/regression/AI/security | **Vitest + Supertest** | `backend/tests/` (49 files, 355 tests) | all pass; coverage 59.4/49.7/60.5/60.2 vs the 58/48/59/58 ratchet |
| Backend coverage | **Vitest v8 coverage** (lcov) + `backend-coverage` artifact | `backend/vitest.config.mts` | gate green on `main` — 59.4/49.7/60.5/60.2 vs 58/48/59/58 |
| Frontend unit + widget tests | **flutter_test** | `frontend/test/` (46 files, 327 tests) | ✅ all pass |
| Frontend coverage | **`tool/check_coverage.dart`** (62% line gate) | `frontend/tool/` | ✅ 62.5% |
| Visual regression | **Flutter goldens** (`matchesGoldenFile`) | `frontend/test/visual/` | ✅ restored (2 goldens) |
| Contract testing | **Pact JS V3** (consumer + provider verification) | `backend/tests/contract/`, `backend/pacts/` | ✅ both halves |
| E2E / compatibility | **Playwright** (Chromium, Firefox, WebKit, Pixel 7) on docker-compose | `e2e/tests/` | ✅ in CI, 4 browser projects |
| Accessibility | **axe-core** (Playwright) + **semantics assertions** (widget tests) | `e2e/tests/a11y.spec.ts`, `frontend/test/widgets/task_card_test.dart` | ⚠️ no Flutter guideline suite |
| End-to-end API contract / black box | **Supertest + Playwright** | `backend/tests/functional/`, `e2e/tests/api-blackbox.spec.ts` | ✅ |
| Performance | **in-process load smoke** (node) + **k6** (staging) | `backend/tests/performance/` | ⚠️ manual-only in CI |
| Regression pinning | **incident-pinning test suite** | `backend/tests/regression/known-issues.test.ts` | ✅ 5 tests |
| Smoke (post-deploy) | **`scripts/smoke-test.mjs`** | `deploy-production.yml` | ✅ |
| Static analysis & quality | **SonarCloud** (Automatic + CI-poll job), **ESLint**, **TypeScript `tsc --noEmit`**, **`flutter analyze`** | `sonar-project.properties`, CI jobs | ✅ |
| Security scanning | **Trivy** (fs + image), **Gitleaks**, **CodeQL** (security-extended), **ZAP Baseline** (weekly DAST), **Dependency Review** | `.github/workflows/ci.yml`, `dast.yml` | ✅ (Dependency Review enabled 2026-11-19) |
| Mutation testing | **Stryker** | — | ❌ not used |
| Monitoring & alerting | **prom-client → Prometheus → (rules + Alertmanager example) → Grafana** | `monitoring/`, `docker-compose.yml` | ⚠️ rules now loaded; delivery is a placeholder |
| Load / soak (staging) | **k6** | `backend/tests/performance/k6-load-test.js` | ⚠️ exists, not scheduled |
| Manual | **Manual test plan** (pre-release checklist) | `docs/testing/MANUAL_TEST_PLAN.md` | ✅ documented |

---

## 2. Testing tools used, by category

### 2.1 Unit testing

- **Vitest** (backend, `^5.1.0`) — chosen over Jest for native ESM, speed and
  first-class TypeScript support. White-box style: mocks Mongoose models via
  `tests/helpers/mocks` and `tests/helpers/authMocks.ts`; covers services,
  middleware, validators, rate limiter, token utils, session cache, and every
  `modules/*` service. Run: `cd backend && npm test`.
- **flutter_test** (frontend) — Flutter's built-in unit-test framework.
  Unit/service/use-case tests live next to the code (`test/models`,
  `test/services`, `test/features/**`) — e.g. `ParseQuickAdd`,
  `AnalyzeSchedule`, `BuildReportSnapshot`, `BuildTaskBreakdown`.

### 2.2 Integration testing

- **Supertest** (`^7.3.1`) against the real Express app with Mongoose mocked
  (`backend/tests/integration/**`) — verifies HTTP → routing → validation →
  controller → service wiring. Shared stubs in `tests/helpers/authMocks.ts`.
- **Shared in-memory Task model** (new, 2026-11-19):
  `backend/tests/helpers/inMemoryTaskModel.ts` implements just enough of the
  Mongoose `Task` surface (create/find/countDocuments/findOneAndUpdate/updateOne
  + chainable `.sort().skip().limit().lean()`) to run the full HTTP pipeline
  without a database. Used by the functional suite and the Pact provider
  verification — one implementation, one behaviour.
- **Widget tests** (`flutter_test`) — real widget trees with mocked HTTP and
  platform channels (e.g. home dashboard, login, startup gate). Semantics
  assertions via `tester.ensureSemantics()`.

### 2.3 Functional / black-box API testing

`backend/tests/functional/tasks.functional.test.ts` drives the real HTTP
pipeline end to end (create → list → get → update → delete, cross-user
isolation, pagination, tag normalisation) asserting only the public contract
(status, body shape, headers). `scripts/smoke-test.mjs` is the post-deploy
black-box check (health 200 / unauthenticated 401 / unknown route 404) run by
`deploy-production.yml`.

### 2.4 End-to-end testing

**Playwright** (`e2e/`) drives real browsers against the docker-compose stack
(MongoDB + backend + nginx + Flutter web). Specs: `smoke.spec.ts`,
`api-blackbox.spec.ts`, `a11y.spec.ts`, `auth.spec.ts`. Browser matrix:
Chromium, Firefox, WebKit and mobile-chrome (Pixel 7). WebKit/Pixel 7 cannot
activate Flutter's semantics tree, so the two semantics-dependent specs skip
on those projects (documented in `e2e/`); everything else runs on all four.
CI: the `e2e` job builds the stack, waits for health, installs browsers with
`--with-deps`, and uploads the Playwright HTML report.

### 2.5 Contract testing

**Pact JS V3** (`@pact-foundation/pact ^17.1.4`), consumer-driven:

- Consumer side — `backend/tests/contract/task.pact.test.ts` with a Pact mock
  server. The consumer test is the **source of truth for the contract** and
  generates `backend/pacts/Auxilia-Frontend-Auxilia-API.json`.
- Provider side — `backend/tests/contract/tasks.provider.test.ts` (new,
  2026-11-19) boots the real Express app on an ephemeral port wired to the
  shared in-memory Task model and verifies the committed pact JSON against it
  (state handlers seed "the authenticated user has at least one task" and
  "the authenticated user can create tasks"; the pact's recorded token is
  accepted via a scoped `verifyAccessToken` stub). Both halves run in
  `npm test`, so CI enforces the contract on every push/PR.
- **Important finding:** the committed pact JSON previously asserted a shape
  the provider never had (`{ success: true }` envelope, `id` primary keys,
  `status: "pending"`, and `status` inside the create body — which the
  provider's `.strict()` zod schema rejects). The consumer contract was
  corrected to the real provider behaviour (`{ message, data }`, `_id`,
  `todo`) before wiring the verifier. A contract that fails against reality
  is worse than no contract.

### 2.6 Visual regression testing

**Flutter goldens** via `matchesGoldenFile` — `frontend/test/visual/golden_test.dart`,
baselines in `frontend/test/visual/goldens/`. The suite had been **deleted**
in f4e5976 "remove flaky golden test blocking CI" and was **restored
2026-11-19** with the flake sources designed out: fixed timestamps (no
wall-clock dependence), no overdue task (no time-dependent branch),
`tester.pumpAndSettle()` to drain the `AnimatedContainer` before capture, and
baselines generated with the same Flutter version CI pins (3.47.8, ubuntu —
Windows vs Linux baselines must match or be regenerated in the CI runner).
Playwright screenshots were deliberately not used — Flutter web renders to
canvas, which is pixel-unstable across engines.

### 2.7 Performance testing

- `backend/tests/performance/load-test.ts` — in-process load smoke: boots the
  real Express app, drives fixed concurrency at the DB-free hot paths, reports
  p50/p90/p95/p99, fails if p95 exceeds the 500 ms budget or any 5xx occurs
  (latest recorded: 65.9 ms p95, `docs/testing/PERFORMANCE_BASELINE.md`).
- `backend/tests/performance/k6-load-test.js` — k6 scenario for staging soak.
  CI: **manual only** (`workflow_dispatch`) — runners are noisy neighbours, so
  it is not a blocking gate. No SLO/error-budget measurement exists yet.

### 2.8 Regression testing (defect pinning)

`backend/tests/regression/known-issues.test.ts` pins every incident fixed in
production-to-be: identifiers validated before Mongo queries (400 not 500),
refresh-token replay revokes the session, password-policy hardening, the
structured 429 contract. **Rule: no defect closes without a regression test.**
Note: the whole CI suite is also a regression net — it runs forever unless a
test is explicitly superseded.

### 2.9 Accessibility testing

- Web: **axe-core** via `e2e/tests/a11y.spec.ts` (critical violations fail;
  serious are reported).
- Flutter: **semantics assertions** in widget tests (`task_card_test.dart` —
  label exposure, toggle label), plus **200% text-scale** widget coverage in
  theme tests.
- The dedicated Flutter accessibility guideline suite
  (`test/accessibility/` — `textContrastGuideline`, tap-target guidelines on
  TaskCard/LoginScreen) that earlier documentation claims **does not exist on
  this branch**. Do not cite it until it is rewritten. (Widget-level semantics
  coverage and the axe scan are real.)

### 2.10 Security testing

| Tool | Scope | Gate |
|---|---|---|
| **Trivy** | filesystem + backend container image, CRITICAL/HIGH, `exit-code 1`; SARIF to code scanning | blocking (`security-scan`) |
| **Gitleaks** | tracked files, network-isolated container scan | blocking (`secret-scan`) |
| **CodeQL** | `security-extended`, javascript-typescript | blocking analysis; SARIF upload conditional on GHAS/fork |
| **OWASP ZAP Baseline** | weekly + backend-touching PRs against `/api/health` | advisory report (`dast.yml`) |
| **Dependency Review** | PR dependency diff, fail on high severity | enabled 2026-11-19 (repo is now public — no GHAS needed) |
| **Lighthouse CI** | web performance/a11y/best-practice budgets | advisory + budgets (`.lighthouserc.json`) |
| **SonarCloud Quality Gate** | bugs/smells/security hotspots; Automatic Analysis read from Checks (opt-in CI-scanner mode also exists, `sonar.qualitygate.wait=true`) | blocking via `CI - Final Quality Gate` |
| **npm audit (prod only)** | production dependency advisories at high severity | blocking (`backend`) |

No `.trivyignore` exists — nothing is suppressed. `.zap/rules.tsv` is empty
(baseline posture, not full scan). No mutation testing (Stryker) — see §6.

### 2.11 Quality and static analysis

**SonarCloud** (Automatic Analysis; the `sonarqube-automatic` job polls the
SonarCloud check-run/API and is wired into `CI - Final Quality Gate`),
**ESLint**, **tsc --noEmit**, **Prettier check**, **`dart format`**,
**`flutter analyze --no-fatal-infos`**, **`console.log`/print sweeps** for
diffs. Branch protection requires `CI - Final Quality Gate` on `main`; PR
ruleset, CODEOWNERS, dismiss-stale-reviews and conversation resolution are
enforced by ruleset (enforce_admins is off; 0 required approving reviews —
hygiene items, see audit).

### 2.12 Monitoring & alerting (production observability — not a test suite, but part of QA evidence)

`prom-client` `/metrics` on the backend (bearer-guarded) →
**Prometheus** (scrape config `monitoring/prometheus.yml`) → alert rules in
`monitoring/prometheus-alerts.yml` (HighErrorRate, HighLatency, BackendDown)
— **these rules were never loaded until 2026-11-19**, when `rule_files` was
added and an **Alertmanager example** (`monitoring/alertmanager.yml`, grouping,
critical severity pages faster) was wired into the `monitoring` compose
profile. **Grafana** dashboards/provisioning under `monitoring/grafana/`.
Delivery is intentionally a placeholder URL; there is no SLO/error-budget
config and no monitoring runbook yet (see §6).

### 2.13 Manual testing

`docs/testing/MANUAL_TEST_PLAN.md` — pre-release checklist (visual polish,
screen-reader flows, AI-copy judgment). Defects found manually must produce an
automated regression test before closure.

### 2.14 Automation & orchestration

**GitHub Actions** (`ci.yml`): backend, frontend, e2e (compose + Playwright),
CodeQL, Gitleaks, Trivy, Dependency Review, Lighthouse, SonarCloud gate,
PR conventions, `ci-summary` → `CI - Final Quality Gate` (the required check).
Plus `release.yml` (tags), `promote.yml` / `deploy-production.yml` (post-deploy
smoke), `rollback.yml`, `sbom.yml`, `dast.yml`. Local orchestration:
`scripts/run-all-tests.mjs [--e2e] [--smoke URL] [--perf]`.

---

## 3. What the tools actually caught (evidence, not theory)

- Calendar routes validated identifiers via express-validator chains but never
  enforced `validationResult` → `/api/calendar` returned 500 on malformed
  input; now 400.
- Refresh-token replay → session revocation added (`4c40f63`), pinned by a
  regression test.
- Secondary-text contrast and steel-blue accent failed WCAG; fixed
  (#7B7F8A→#5A5F6A, #6B7C98→#4F5D75, white primary-button text in light mode,
  dark-mode auth screens, 48px touch targets) — surfaced by the a11y work.
- SonarCloud quality gate held the release until hotspots were triaged.
- The Pact consumer contract described an API that never existed; provider
  verification caught the drift immediately on its first run.
- Weak passwords accepted; policy hardened; regression-pinned.

---

## 4. Coverage and quality gates (current values)

| Gate | Value | Where enforced |
|---|---|---|
| Backend statements / branches / functions / lines | **58 / 48 / 59 / 58** (ratchet; measured 60.98/51.26/62.18/61.63 at raise time) | `backend/vitest.config.mts` thresholds; CI `test:coverage` |
| Frontend line coverage | **62%** | `ci.yml` → `dart run tool/check_coverage.dart 62` |
| Frontend measure | 62.5% (7906/12659 lines) | same |
| Backend measure (on `main`, 2026-11-19) | 59.42 / 49.72 / 60.46 / 60.22 | **gate GREEN** |
| SonarCloud | Quality gate must pass | `CI - Final Quality Gate` |
| Trivy | CRITICAL/HIGH must be absent in fs + image | `security-scan` |

---

## 5. Tool choices (why, not just what)

- **Vitest over Jest** — native ESM, faster cold starts, built-in coverage
  (v8), same config style as the rest of the toolchain.
- **Supertest** — no listener needed, perfect for HTTP contract assertions.
- **flutter_test** — first-party, deterministic (fixed `Ahem` test font),
  drives real widget trees without a device, same binary family as CI.
- **Playwright** — one API for three engines + mobile emulation, strong
  auto-waiting and web-first assertions, traces on failure.
- **Pact** — consumer-driven contract testing closes the gap between the
  Flutter client's expectations and the Express provider's reality; catches
  integration drift unit tests and black-box E2E cannot.
- **Trivy + Gitleaks + CodeQL + ZAP** — defence in depth: dependencies/image,
  secrets, code patterns, live DAST. ZAP deliberately stays a baseline scan
  (weekly), not a pentest.
- **Prometheus/Grafana/Alertmanager** — standard metrics, SLO-friendly
  ruleset, and a clear path from metric → alert → receiver.
- **k6 (optional) + in-process load smoke** — the smoke gives a cheap p95
  signal in every local run; k6 is there for serious staging load.
- **No Stryker / no mutation testing** — not adopted yet (see §6).

---

## 6. Honest gaps (what is NOT covered)

1. **Stryker mutation testing** — absent everywhere. `test:coverage`
   thresholds and incident-pinned regression tests are the only mutation-risk
   mitigation today.
2. **MongoDB-backed integration tests** — no `mongodb-memory-server` or
   `testcontainers`; everything above E2E mocks Mongoose. The real `mongo:7`
   only backs docker-compose and E2E.
3. **Flutter integration testing** — `frontend/integration_test/app_test.dart`
   exists but never runs in CI; no device/emulator matrix.
4. **Coverage must stay green on new modules** — `main` is green today
   (59.4/49.7/60.5/60.2, re-measured 2026-11-19). Any feature branch that
   ships modules without tests will trip the ratchet; the fix is tests, not
   a lower threshold.
5. **Flutter accessibility guideline suite** — missing (see §2.9).
6. **Regression-run evidence** — `tests/regression/known-issues.test.ts` runs
   and passes in CI, but `RELEASE_EVIDENCE_v1.0.0.md` remains a blank template;
   no filled regression-run artifact exists for a release.
7. **Performance gating** — manual-only; no staging SLO/error-budget
   measurement; no alert on latency from production metrics.
8. **Monitoring delivery** — alert rules load now, but Alertmanager points at
   a placeholder webhook; no Slack/PagerDuty receiver, no monitoring runbook.
9. **DAST posture** — ZAP baseline (not full scan), empty `.zap/rules.tsv`.
10. **Supply chain** — SBOM SLSA attestation is gated off (private-repo
    heritage); Dependency Review only enabled 2026-11-19.

---

## 7. Notes for this PR

### 7.1 Backend coverage gate is GREEN on `main`
Re-measured on `main` with this PR applied: 59.42 / 49.72 / 60.46 / 60.22
statements / branches / functions / lines against the 58/48/59/58 ratchet;
355 tests pass. (An unmerged working branch elsewhere in this repo is red
because it ships new modules without tests — that is that branch's problem,
not this PR's.)

### 7.2 Dependency Review turned on (repo setting, 2026-11-19)
The repo is public (it was private during the original audit, which is why the
job was disabled). `DEPENDENCY_REVIEW_ENABLED=true` was set via `gh variable
set`; `ci.yml` needed no changes — the job was already written to be opt-in.
Verified: `gh variable list` shows the value set 2026-11-19T07:28Z. High-severity
dependency advisories on PR diffs will now block the gate.

### 7.3 What this PR carries
New: `backend/tests/contract/tasks.provider.test.ts` (Pact provider
verification), `backend/tests/helpers/inMemoryTaskModel.ts` (shared
in-memory Task model), `frontend/test/visual/golden_test.dart` (restored,
flake-free visual-regression suite), `monitoring/alertmanager.yml` (example
Alertmanager config), this report. Modified:
`backend/tests/contract/task.pact.test.ts` (consumer contract corrected to
the real provider behaviour), `backend/pacts/Auxilia-Frontend-Auxilia-API.json`,
`backend/tests/functional/tasks.functional.test.ts` (refactor only — same
in-memory model now shared with the provider verification), `monitoring/prometheus.yml`
(loads `prometheus-alerts.yml` via `rule_files`, routes alerts to
Alertmanager), `docker-compose.yml` (monitoring profile mounts the rule file
and adds Alertmanager :9093), `.gitignore` (ignore golden-failure
artifacts), `docs/testing/TESTING_STRATEGY.md` (corrected to measured
reality), `frontend/test/visual/goldens/task_card_completed.png` (baseline
refresh — #98/#109 restyled the completed card's accent; the pending-card
baseline is untouched).
Verification: backend contract + functional ✅, backend coverage gate ✅,
lint ✅, frontend 327/327 ✅ + goldens ✅ + 62.5% ≥ 62 gate ✅. Docker Desktop
was not running, so `promtool check config` could not be executed — the
monitoring YAML and `docker compose config` were validated instead.

## 8. How to run everything

```bash
# Backend — full suite with coverage (fails under the ratchet):
cd backend && npm run test:coverage

# Backend — just the contract layer (consumer + provider verification):
cd backend && npm run test:contract

# Frontend — all tests with coverage; then enforce the 62% line gate:
cd frontend && flutter test --coverage && dart run tool/check_coverage.dart 62

# Frontend — visual regression only:
cd frontend && flutter test test/visual

# Monitoring stack (Prometheus :9090, Alertmanager :9093, Grafana :3001):
docker compose --profile monitoring up -d

# Everything, including the docker-compose stack + Playwright E2E:
node scripts/run-all-tests.mjs --e2e
```
