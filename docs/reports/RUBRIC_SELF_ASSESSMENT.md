# CA1 Rubric Self-Assessment — Auxilia (ST0529)

Date: 15 November 2026 · Assessor: Keefe Chen (self-assessment for CA1) ·
Rubric: AY26/27 ST0529 CA1 (Singapore Polytechnic, School of Computing)

This document scores the project against the six published evaluation criteria,
with evidence for every claim. It is deliberately honest: where work is unfinished
or evidence is missing, the score reflects that rather than aspiration.

**Weighted estimate: ≈ 83.5% of the CA1 mark (≈ B+)**, contingent on executing
the release and the live demonstration (see criteria 3 and 6).

| # | Criterion | Weight | Score /10 | Weighted |
|---|-----------|--------|-----------|----------|
| 1 | Project Management | 10% | 8.0 | 8.0 |
| 2 | Quality Assurance | 20% | 8.0 | 16.0 |
| 3 | Integration and Delivery Pipeline | 20% | 9.0 | 18.0 |
| 4 | Software Development and Deployment | 20% | 8.0 | 16.0 |
| 5 | Independent Research and Learning | 20% | 9.0 | 18.0 |
| 6 | Presentation and Demonstration | 10% | 7.5 | 7.5 |
|   | **Total** | **100%** | | **≈ 83.5** |

---

## 1. Project Management — 8.0/10

**What went well**

- Solo, self-directed delivery over 27 Oct – 15 Nov 2026: **240 commits**,
  62 merges, ~59 remote branches; trunk-based flow with `feature/`,
  `bugfix/`, `hotfix/`, `refactor/` prefixes enforced by a CI job
  (`pr-conventions`) and a documented branching model
  (`docs/release/BRANCHING.md`).
- Full planning artefacts: `docs/planning/PROJECT_PLAN.md`,
  `docs/planning/TASKS.md`, and (new) `docs/planning/USER_STORIES.md` with
  acceptance criteria per story.
- Jira traceability (NP-*/AUX-* keys) from board → report → code; PR template
  enforces Conventional Commits; CODEOWNERS; Dependabot (npm/pub/github-actions).
- Living documentation: 20 docs files across planning/testing/release/compliance.
- Honest status tracking: `USER_STORY_CICD_REPORT.md` explicitly refuses to
  call NP-16 done while the release remains unexecuted.

**What cost marks**

- Documentation drifted from reality repeatedly (group workspace still labelled
  "Planned" in the plan, test counts disagreed across five files, stale
  "Personal Secretary API" header) — corrected on 15 Nov 2026, but the drift
  existed for days of sprint work.
- Scope grew continuously (sync, groups, MFA, AI, monitoring), finishing a full
  3.5-week sprint on a long-lived `feature/enterprise-cicd-pipeline` branch.
- Duplicate Jira key (NP-45 used for two stories) never cleaned up on the board.

**To raise the score:** cut releases on a fixed cadence; re-sync docs each
sprint close (a `docs-drift` check in CI); close/split NP-16 into its gates.

## 2. Quality Assurance — 8.0/10

**What went well**

- **Coverage gates that can only ratchet upward:** backend Vitest thresholds
  49% statements / 39% branches / 48% functions / 50% lines (excludes only what
  is documented: groups/audit/roadmaps pending tests); frontend 60% line-coverage
  gate via `tool/check_coverage.dart`. CI fails below the gate.
- **344 backend tests (45 files), 326 frontend tests (47 files)**, all passing
  (verified 15 Nov 2026), plus **6 new widget tests** for the rewritten reminders
  hub added today (empty state, overdue/upcoming grouping, complete, snooze,
  add-reminder dialog).
- **15 testing disciplines** mapped in `docs/testing/TESTING_STRATEGY.md`:
  unit, integration, functional, regression, contract (Pact), AI guardrails
  (prompt injection/output schema), security (headers/CORS/rate limit),
  performance (k6 + latency budget), accessibility (axe in Playwright + Flutter
  a11y guidelines + 200% text scale), visual goldens, smoke vs production.
- API contract testing with Pact (consumer `Auxilia-Frontend-Auxilia-API`).
- Playwright E2E on 4 projects (Desktop Chrome/Firefox/Safari, Pixel 7) wired
  into `ci.yml` against the docker-compose stack, incl. an a11y spec (axe).

**What cost marks**

- Backend line coverage ≈ 50% against an aspirational 80%; the groups, audit and
  roadmaps modules ship untested at controller/integration level and are excluded
  from the ratchet to make the gate pass honestly rather than be lowered.
- No E2E journey for signup → task creation → offline edit → reconnect →
  conflict resolution (explicitly flagged as residual risk in the CI/CD report;
  see BACKLOG-9).
- Trivy security scans are report-only (not blocking); three coexisting API
  response envelopes with no enforcement; no frontend-driven HTTP assertion.
- Reminders screen had no tests and a dead Add-reminder path until 15 Nov 2026.

**To raise the score:** un-exclude groups/audit from the coverage exclusion;
add the full-journey E2E; promote Trivy to blocking on CRITICAL; contract-test
the remaining endpoints; grow the backend baseline each sprint.

## 3. Integration and Delivery Pipeline — 9.0/10

**What went well**

- **12-job GitHub Actions pipeline** (`ci.yml`) with concurrency cancellation of
  superseded runs, plus a single required aggregate gate (`ci-summary`) that is
  the branch-protection rule:
  `dependency-review` (high-severity blocks) → `pr-conventions` →
  `security-scan` (Trivy fs + image build scan, SARIF to code scanning) →
  `secret-scan` (gitleaks, exit-code 1) → `codeql` (security-extended) →
  `backend` (npm ci, audit, typecheck/eslint, coverage gate, build) →
  `frontend` (format, analyze, coverage ≥60%, release web build) →
  `e2e` (compose stack + Playwright, HTML report artefact) → `performance`
  (opt-in) → `sonarqube`/`sonarqube-automatic` (quality-gate wait) → `ci-summary`.
- **Release engineering:** `release.yml` verifies tag == package.json ==
  pubspec, re-runs all gates from clean installs, packages the web build,
  attests **build provenance** (`attest-build-provenance`), and publishes a
  GitHub release. `deploy-production.yml` triggers the Render deploy hook,
  polls `/api/health` for up to 10 minutes and runs the read-only
  `scripts/smoke-test.mjs`.
- **Jenkins parity:** all-in-one root `Jenkinsfile` (checkout → backend →
  frontend → approval-gated deploy) with a custom agent image
  (`jenkins/Dockerfile`: Jenkins LTS JDK 21 + Node 22.14 + Flutter 3.47.8).
- Production definition as code: `render.yaml` (Singapore, health checks,
  secret sync-disabled) + `docker-compose.yml` (non-root backend, nginx-unprivileged
  frontend, optional `jenkins` and `monitoring` profiles) + digest-pinned base images.
- Observability: Prometheus scrape of guarded `/metrics` + provisioned Grafana
  dashboard (local profile, documented).

**What cost marks**

- **The release has never been executed.** No `v1.0.0` tag exists; `release.yml`
  and `deploy-production.yml` are configured but unproven against production;
  manual NFR gates (HTTPS/CORS in prod, DB backup, rollback rehearsal, screen
  reader on device) are unevidenced.
- Smoke test is read-only and shallow (health/401/404); no post-deploy data-write
  canary.
- SonarCloud gate enforced via a repo-variable fallback dance; Trivy advisories
  triaged per release, not blocked.

**To raise the score:** execute `v1.0.0` end-to-end and attach the run; enable
Trivy as a blocking gate for CRITICAL; add a synthetic post-deploy write test
against a dedicated smoke account.

## 4. Software Development and Deployment — 8.0/10

**What went well**

- A genuinely working product: Flutter (Material 3, Riverpod, responsive
  shell: bottom bar <600 px, rail ≥600 px, sidebar ≥1024 px) with dark/light
  themes, bundled Inter, a token-based design system (`AppSpacing/AppSizes/AppRadius`)
  and ~25 reusable `core/widgets/` components used across every screen.
- **Offline-first correctness:** versioned storage envelope with one-way
  migration and corrupt-record tolerance; durable coalescing change queue;
  retry/backoff with dead-lettering; app-lifecycle background sync; whole-task
  conflict detection with "Keep mine/Use server"; per-owner scoping.
- **Security-conscious backend:** Express 5 + TypeScript strict; JWT access
  with single-flight refresh; bcrypt; helmet/hpp/CORS allowlist; global rate
  limiting; zod validation; `$jsonSchema` Mongo validators; TOTP MFA; password
  reset with single-use hashed tokens; admin RBAC; audit log module;
  Prometheus metrics guarded by token/admin.
- **Deployability:** docker-compose stack builds clean; backend runs as non-root
  with `npm`/`npx` removed from the runtime image; frontend served by
  nginx-unprivileged with a strict CSP (no `unsafe-inline` scripts); Render
  Singapore blueprint; Trivy-clean base-image claims verified in CI.
- **Accessibility as engineering work:** WCAG AA contrast pass, 200% text-scale
  tests, semantic labels on the shared component library (badges, cards,
  loading/empty/error states) — extended 15 Nov 2026 (StatusBadge label,
  CompletionBar percentage label, AppCard `button: true` semantics).

**What cost marks**

- Deployment never demonstrated end-to-end; two Mongoose `User` schemas (first
  registration wins — confusing, unresolved); OWASP mapping shows several
  categories only "partially implemented" (A01/A02/A03/A05/A06/A08/A09/A10).
- Reminder/sync system is in-app only (no OS notifications; whole-task conflict
  merge can silently overwrite after an explicit "Keep mine").
- Shared preferences not encrypted at rest; groups lifecycle gap (group delete
  cascade, audit UI) unfinished; assistant chat history not persisted.

**To raise the score:** resolve the duplicate `User` schema; finish OWASP A08
(software integrity attestation verification in deploy); OS notification spike;
execute and screenshot a real Render deployment with health checks green.

## 5. Independent Research and Learning — 9.0/10

**What was learned and applied (beyond lecture scope)**

- Supply-chain security engineering: digest-pinned images, Trivy fs/image
  scanning with SARIF upload, gitleaks, CodeQL security-extended,
  dependency-review, SBOM-adjacent provenance attestation — beyond course
  requirements and documented in `docs/compliance/OWASP_IMPLEMENTATION.md`.
- Advanced auth: single-flight JWT refresh with subject-claim matching, token
  family reasoning, TOTP MFA, reset-token hashing, Turnstile CAPTCHA (web).
- Distributed-systems practicalities: offline-first sync, idempotency via base
  timestamps, optimistic conflict resolution, dead-letter queues, backoff.
- Contract testing (Pact V3→V4 upgrade noted in test output), k6 load smoke
  with explicit latency budgets, AI guardrail testing (prompt-injection
  resistance, output schema enforcement).
- Cloud/deployment: Render blueprints, health-check gating, nginx CSP,
  Prometheus/Grafana provisioning as code, GitHub Environment-gated deploys.
- Accessibility engineering: WCAG AA contrast remediation (see commit
  `3da46fd`), 200% text-scale verification.
- 240 commits of self-directed work over ~3.5 weeks with no starter template —
  architecture, testing, CI/CD, deployment and docs were all designed and
  built independently.

**What cost marks**

- Breadth exceeded depth in places: the AI/LLM provider path was never
  exercised against a real provider; the rubric-to-roadmap AI workflow
  (the project's most novel research area) is still only scaffolded.

**To raise the score:** one deep spike completed and written up (e.g. field-level
CRDT merge or a real rubric-parse evaluation on three authentic course rubrics),
with before/after measurements.

## 6. Presentation and Demonstration — 7.5/10 (pending live demo)

**Demo readiness evidence**

- Deployable stack: `render.yaml` (live blueprint), local `docker compose up`
  serves the full app on :8080 with a working backend on :3000; `.env.example`
  documents every variable; `npm run seed:demo` provisions demonstration
  administrator and standard accounts (refused in production without
  `ALLOW_DEMO_SEED=true`).
- Manual test plan (`docs/testing/MANUAL_TEST_PLAN.md`, 9 sections) covers the
  demo-critical paths; README documents demo accounts and observability profile.
- Reports/docs make the system explanation easy: architecture, ADRs in docs/,
  and (new) `docs/planning/USER_STORIES.md` gives per-story evidence.

**What cost marks**

- The live demo has not been rehearsed against production; Render free tier
  cold-starts (≈50 s) would eat demo time if that is the demo target.
- No production release has been executed from this workspace; a demo of the
  sync-conflict flow needs two devices/sessions — awkward but doable.
- Presentation marks depend on delivery, which cannot be evidenced in a repo;
  the 7.5 is demo-readiness, not performance.

**To raise the score:** rehearse a 6-minute scripted demo (guest → sign up →
task + reminder → offline airplane-mode edit → reconnect → conflict resolve →
AI quick-add → admin console → Grafana); print the release checklist as the
health-walk artifact; deploy v1.0.0 beforehand so the demo runs against the
"production" URL.

---

## Improvements applied on 15 November 2026 (this assessment)

1. **Reminders hub rewritten** to the offline-first `TaskStore` model: grouped
   Overdue/Today/Upcoming sections, complete/snooze/clear actions, working
   loading/error/empty states via the shared design system.
2. **"Add reminder" implemented** (was a TODO snackbar): stand-alone reminder
   task or attach-to-existing-task, inline date/time validation mirroring
   `validateSchedule`, inline past-time rejection.
3. **Orphaned backend reminder client deleted** (raw Dio, hard-coded
   `http://localhost:3000/api`, no auth, wrong response envelope); unused
   dependencies `dio` and `json_annotation` removed (`speech_to_text` was
   confirmed in use and retained).
4. **Routing defects fixed:** `/reminders` and `/groups` accept typed args
   (`RemindersArgs`, `GroupsArgs`) carrying a live `TaskStore` + `Session`;
   dashboard "View all" navigates to the reminders hub sharing state.
5. **Six new widget tests** for the hub; full suite green (**326/326**).
6. **Core widgets polished:** `StatusBadge`/`CompletionBar` semantics,
   `AppCard` `button: true`/`enabled` semantics for tappable cards.
7. **Docs re-synced with reality:** PROJECT_PLAN (groups/sync/password reset now
   marked Implemented; phases re-scoped; entities/API corrected; MFA, audit,
   rubric/roadmap scaffolding recorded), backend Jenkinsfile header de-staled,
   README test counts corrected (344 backend / 326 frontend), release notes and
   documentation index updated, `docs/planning/USER_STORIES.md` written.
8. **Rubric self-assessment** (this document).

## Honest outlook / grader notes

- The single largest mark risk is criterion 3 and 6 hingeing on an **unexecuted
  release**: until `v1.0.0` is tagged and the deploy workflow is watched end to
  end, "deployment" is configuration, not evidence.
- Second risk: **QA depth** — half the backend is covered and the flagship
  groups module is carved out of the ratchet to keep the gate green.
- Third risk: **manual gates** (screen reader, 200% device pass, rollback
  rehearsal, HTTPS/CORS, backup) are all unverified.
- Everything else — pipeline rigour, testing breadth, security posture,
  documentation volume, and genuinely broad independent learning — is unusually
  strong for a Stage-2 individual CA.
