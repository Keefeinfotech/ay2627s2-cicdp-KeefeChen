# SQA, V&V, Testing & Change Governance Audit — Auxilia

**Audit date:** 22 November 2026
**Auditor role:** Senior SQA & Release Governance Architect
**Scope:** Repository at `HEAD` (`78582a0`), local documentation, test plans,
automated suites, GitHub Issues/PRs (queried live via `gh`), CI/CD workflows and
change-management artifacts. No external Jira board or CMDB was made available;
where evidence lives outside the repository it is reported as such.

**Status key:** Implemented · Partially Implemented · Missing · Cannot Verify from Provided Files

**Overall SQA & Change Governance Readiness: 7.0 / 10**
(Strong automation and disciplined process documentation; formal governance
artifacts — RTM, defect log, SQA metrics, CCB/CAB separation — are absent.)

---

## 1. Requirements & Traceability (RTM)

**Status: Partially Implemented**

**Findings**

- Requirements exist in usable form: `docs/planning/USER_STORIES.md` (stories
  with `NP-*`/`AUX-*` keys, priority, points, testable acceptance criteria,
  Definition of Done), `docs/compliance/NFR_RELEASE_GATES.md` (NFRs G1–G14
  with verification method), `docs/planning/PROJECT_PLAN.md` (scope, phases,
  status key), `docs/architecture/ERD.md` (data model).
- A **story-level** traceability table exists: `USER_STORIES.md` §"Traceability
  summary" maps story → primary implementation → primary tests.
- `docs/reports/USER_STORY_CICD_REPORT.md` gives story-by-story status with CI
  run evidence; `docs/reports/RELEASE_EVIDENCE_v1.1.md` gives release-level
  verification.
- **No Requirements Traceability Matrix exists**: no document maps a requirement
  ID to design artefact → implementation file → test case ID → test result →
  release. `docs/architecture/ERD.md` explicitly refers to an external SRS that
  is not in the repository. Jira (NP/AUX keys) is referenced but not exported.

**Actionable Fix**

1. Create `docs/quality/RTM.md` with exactly these columns:
   `Req ID | Req text (short) | Source (story/NFR) | Design ref (ERD/ADR) | Implementation ref (file path) | Test case IDs (auto + M-xx) | Test result | Release/evidence link | Status`.
2. Number requirements as `FR-001…` (from `USER_STORIES.md`) and `NFR-G01…`
   (from `NFR_RELEASE_GATES.md`); reuse existing test names as IDs (e.g.
   `BVA-upper boundary: limit=100`, `M-20`, `tests/contract/task.pact.test.ts`).
3. Start with a 20-row "critical path" RTM (auth, task CRUD, sync/conflict,
   AI guardrails, deploy gates) rather than trying to catalogue all 20 stories
   at once; link it from `README.md` and `RELEASE_CHECKLIST.md`.

---

## 2. Verification & Validation (V&V) Balance

**Status: Partially Implemented**

**Findings**

- **Verification (building it right) is strong:** `npm run typecheck`,
  `flutter analyze`, `dart format`, lint, 378 backend + 330 frontend tests,
  coverage ratchets (58/48/59/58; 62%), Pact contract verification, Trivy,
  Gitleaks, CodeQL, SonarCloud, Stryker, dependency review — all wired into
  `.github/workflows/ci.yml` and summarised in `TESTING_STRATEGY.md` and
  `NFR_RELEASE_GATES.md`.
- **Validation (building the right system) exists as design, weaker as
  evidence:** user stories with acceptance criteria and personas,
  `docs/testing/MANUAL_TEST_PLAN.md` (38 user-facing cases), `docs/DEMO_SCRIPT.md`
  and a committed demo recording, live production health/smoke evidence.
- The gap is **execution evidence**: the manual plan has no recorded results,
  and the manual NFR gates (screen reader, physical-device 200% scale,
  HTTPS/CORS check, DB backup, rollback rehearsal) are listed as unexecuted in
  `docs/reports/RELEASE_EVIDENCE_v1.1.md`.

**Actionable Fix**

1. Add a "Validation results" table to each release evidence file:
   `Manual case ID | Executed by | Date | Environment | Result | Defect ID`.
2. Execute and record at least two manual validation cases per release
   (M-05 200% text scale, M-32 screen reader) and one end-user acceptance
   sign-off against the story acceptance criteria.
3. Keep verification as-is; label the two halves explicitly in
   `TESTING_STRATEGY.md` with a "V&V map" table so a reviewer can see the
   balance at a glance.

---

## 3. Code Reviews & Quality Tools

**Status: Partially Implemented**

**Findings**

- Systematic PR workflow: **134 PRs (108 merged)**, Conventional Commit titles,
  branch-name enforcement, `.github/pull_request_template.md` requiring reason,
  impact assessment, testing evidence, security considerations, regression
  risks and rollback steps, `.github/CODEOWNERS`, protected `main`/`develop`,
  single required `CI - Final Quality Gate`.
- Static/dynamic tooling is broad: ESLint, `tsc --noEmit`, Prettier,
  `flutter analyze`, `dart format`, Trivy, Gitleaks, CodeQL (security-extended),
  SonarCloud, Lighthouse CI, OWASP ZAP baseline, Stryker, Pact. AI-assisted
  fixes appear as `Co-authored-by: Copilot Autofix powered by AI`.
- **Review depth is the weak point:** analysis of PR review data shows 14 PRs
  with any review; most are the author approving their own Dependabot PRs,
  and several feature PRs have only GitHub Advanced Security bot comments.
  Zero independent human approvals on the main feature PRs; branch protection
  requires 0 approving reviews. No pair-programming or formal inspection
  records. `CODEOWNERS` points at team handles (`@Keefeinfotech/backend-team`
  etc.) — verify those teams exist; if this is a personal account, the owners
  will not resolve.

**Actionable Fix**

1. Add `docs/development/CODE_REVIEW_POLICY.md` with risk tiers:
   `Tier 1 (auth, crypto, migrations, CI/CD, secrets)` = 1 independent reviewer
   **or** documented formal self-inspection using a checklist; `Tier 2` =
   normal PR + green gates; `Tier 3 (docs/dependabot)` = self-review.
2. For Tier 1, require a filled inspection checklist in the PR: correctness,
   security, error handling, test coverage, rollback plan, docs updated.
3. Replace unresolved CODEOWNERS team handles with real users/teams, and set
   `required_pull_request_reviews` to at least 1 for `main` on Tier-1 paths
   where a second person is available.

---

## 4. Test Plan Completeness

**Status: Partially Implemented**

**Findings**

- Strong component pieces: `docs/testing/TESTING_STRATEGY.md` is a living map
  (15 disciplines, where tests live, how to run, CI gating, ratchets, gaps),
  `docs/testing/MANUAL_TEST_PLAN.md` (scope, when/who/environment, 38 cases,
  release gate), `docs/compliance/NFR_RELEASE_GATES.md` (gate IDs, blocking
  status, exceptions process), `docs/release/RELEASE_CHECKLIST.md` (7 phases).
- **No single consolidated Test Plan** containing all of: release scope,
  schedule, objectives, strategy, environment/data setup, deliverables, and
  explicit Entry / Exit / Suspension criteria. Exit criteria are implicit in
  the gate tables; suspension criteria do not exist anywhere.
- **Documentation drift found:** `RELEASE_CHECKLIST.md:39,45` still states a
  **60%** frontend coverage gate while CI, Jenkins and
  `QA_VERIFICATION_2026-11-21.md` enforce **62%**. `DEPENDENCIES.md:39-40`
  says "there is no bot configuration in the repository", but
  `.github/dependabot.yml` exists. `QA_VERIFICATION_2026-11-21.md` claims all
  docs were aligned — this is not fully true.

**Actionable Fix**

1. Create `docs/testing/TEST_PLAN.md` with these sections:
   `1 Purpose & objectives | 2 Release scope (in/out) | 3 Schedule & milestones |
   4 Strategy (test levels/types, tools, automation split) | 5 Environment &
   test data (local, compose stack, CI, Render staging, demo accounts) |
   6 Entry criteria | 7 Exit criteria | 8 Suspension & resume criteria |
   9 Deliverables (test summary report, coverage artifacts, evidence links) |
   10 Risks & contingencies | 11 Sign-off`.
2. Suggested entry criteria: branch green on required CI gates; environment
   provisioned; test data seeded via `npm run seed:demo`; known defects triaged.
   Exit: all blocking gates green, 0 open Critical/High defects, manual plan
   complete, smoke 3/3, evidence files attached. Suspension: critical
   environment outage, >25% test failures, data-loss defect, security gate red.
3. Fix the two stale statements above in the same PR (60% → 62%; remove the
   "no bot configuration" sentence).

---

## 5. Test Scenarios & Test Case Coverage

**Status: Partially Implemented**

**Findings**

- Coverage across types is genuinely broad: unit (Vitest, flutter_test),
  integration (Supertest + mongodb-memory-server), functional/black-box API,
  UI/widget + golden visual tests, database (schema/index/CAS/soft-delete/
  ownership tests in `tests/mongodb/`), security (auth, rate limit, CORS, CSP,
  AI injection guardrails, ZAP), usability/accessibility (axe + Flutter
  guideline suite, 200% text scale), regression (incident-pinning suite),
  contract (Pact), E2E (Playwright × 4 browsers), performance (p95 budget).
- Design techniques are explicitly named in
  `backend/tests/unit/validators/task.query-design.test.ts` (EP, BVA, UC) and
  `user.validation.test.ts` (equivalence partitioning).
- `MANUAL_TEST_PLAN.md` cases contain **steps and expected** only — no explicit
  preconditions, input data, or separate expected-result field; no recorded
  actual result / pass-fail / defect ID per case.
- Remaining coverage gaps are documented honestly: groups/audit/roadmaps
  excluded from backend coverage ratchet; Mongo-backed tests cover the tasks
  module only; Stryker scoped to two files.

**Actionable Fix**

1. Add `docs/testing/TEST_CASE_CATALOGUE.md` with one row per scenario:
   `TC ID | Scenario | Type | Preconditions | Test data | Steps | Expected result | Automated counterpart (test ID/file) | Actual | Status | Defect ID`.
   Convert the 38 manual cases into this format (add preconditions and data).
2. Link each TC ID to the RTM from area 1 so requirement → test case → result
   is one click away.
3. Adopt the stated ratchet policy: un-exclude **one** module per release
   (start with `groups`) and add controller/integration tests, never lower the
   threshold.

---

## 6. Quality Metrics & Measurement

**Status: Partially Implemented**

**Findings**

- Coverage and test-result metrics are tracked rigorously and repeatedly:
  backend 59.84/50.34/61.09/60.66 vs 58/48/59/58; frontend 62.5% vs 62%;
  Stryker 100.00 on two files; Pact 3/3; Mongo 8/8; 378/330 tests; p95 baseline
  in `docs/testing/PERFORMANCE_BASELINE.md`. Evidence files:
  `QA_VERIFICATION_2026-11-21.md`, `REGRESSION_RUN_2026-11-19.md`,
  `TESTING_TOOLS_REPORT.md`.
- A repository-wide search found **no** Defect Density, Defect Detection
  Efficiency (DDE), Escaped Defects, defect leakage, or MTTR figures. Release
  readiness is judged from coverage + green gates only, not from defect
  analytics.

**Actionable Fix**

1. Create `docs/quality/QUALITY_METRICS.md` and record per release:
   - **Defect Density** = confirmed defects / KLOC (generate KLOC with `npx cloc . --exclude-dir=node_modules,build,coverage`).
   - **DDE** = defects found before release ÷ (pre-release + post-release defects) × 100.
   - **Escaped Defects** = production incidents/defects found after each release (target 0 Critical).
   - Supporting: test pass rate, coverage deltas, mutation score, flaky-test count, CI green rate.
2. Set exit thresholds, e.g. DDE ≥ 80%, 0 escaped Critical defects, no coverage ratchet regression.
3. Populate one row per release in `RELEASE_EVIDENCE_v1.1.md` and require the
   table in the release checklist.

---

## 7. Defect & Issue Log Management

**Status: Partially Implemented**

**Findings**

- Templates exist: `.github/ISSUE_TEMPLATE/bug_report.md` includes summary,
  reproduction steps, expected/actual, environment, severity, last-known-good
  commit, logs, and impact assessment. Issue **#69** is a strong worked example
  (severity via label, repro, expected/actual, CI run URLs, log excerpt,
  assignee, acceptance criteria, closed with fix).
- **The log is not maintained in the repository:** live query returns only
  **2 issues total** (1 open change request #125, 1 closed bug #69); 0 issues
  have a milestone, 1 has an assignee. Meanwhile `git log` contains **115**
  `fix:`/`hotfix:` commits and the documentation references many `NP-*`/`AUX-*`
  defects on an external Jira board that is not exported.
- Missing attributes in the template/record: explicit priority (severity only),
  reproducibility (always/intermittent), assigned owner field, target date, and
  resolution status/verification fields. No escaped-defect tracking.

**Actionable Fix**

1. Create `docs/quality/DEFECT_LOG.md` with columns:
   `Defect ID | Title | Severity | Priority | Reproducibility | Steps | Detected in (phase/build) | Owner | Target date | Status | Fix commit/PR | Regression test ID | Escaped? (Y/N) | Closed date`.
2. Backfill the 15–20 highest-impact entries from `git log --format='%h %ad %s' --grep='^fix'` and the external Jira board; link each to its regression test.
3. Extend `bug_report.md` with `Priority`, `Reproducibility`, `Target date`, `Assigned owner`, `Regression test linked` fields; require a milestone on every bug.

---

## 8. Change Strategy & Governance (CCB / CAB)

**Status: Partially Implemented**

**Findings**

- Change strategy is well documented: `docs/change-management/change-management-process.md` defines roles, submit→evaluate→approve/reject/defer→implement→review→test→merge→close, emergency hotfix procedure, impact criteria and extra verification for high-impact areas.
- Rollback readiness is strong: `.github/workflows/rollback.yml` deploys an exact last-known-good SHA via Render API, polls `/api/health` and runs smoke; `LAST_GOOD_SHA` is persisted by `deploy-production.yml`; failed deploys auto-rollback; `docs/deployment/ROLLBACK_RUNBOOK.md` gives steps and verification.
- CAB/CCB are **not explicitly separated**: no document defines a Change Control Board vs a Change Advisory Board, membership, cadence, authority or meeting records. `approval.yml` uses the `approval` environment but says "Until configured, this job runs without a manual gate"; production deploys are triggered automatically by green CI (no explicit CAB approval record). Required approving reviews = 0 by design.

**Actionable Fix**

1. Create `docs/change-management/GOVERNANCE.md`:
   - **CCB** (project/design changes): owner + maintainer; meets at sprint boundaries; approves scope, architecture, schema, API contract changes; output = decision ID recorded on the change issue.
   - **CAB** (production deployment): release owner + on-call; meets before each production release or emergency; approves deploy/rollback; output = `CAB-YYYYMMDD-nn` recorded in release evidence.
   - Authority matrix for Standard / Normal / Emergency changes and who may waive which gate (security/privacy gates G8–G10 are non-waivable per NFR gates).
2. Configure required reviewers on the `production` and `approval` GitHub Environments; make `deploy-production.yml` wait on the approval environment for Normal/High-risk releases.
3. Add a `CAB decision ID` field to `RELEASE_EVIDENCE_*` and `change-log.md`.

---

## 9. Change Request Process & Documentation

**Status: Partially Implemented**

**Findings**

- A genuine structured Change Request Form exists: `.github/ISSUE_TEMPLATE/change_request.md` with description, justification, proposed implementation, 8-area impact table, priority, risks/mitigation, acceptance criteria, related requirements and approval decision. Issue **#125** is a fully filled, high-quality example (including residual-risk link R-1 and acceptance criteria).
- `change-management-process.md` defines emergency bug-fix handling and mandatory documentation updates (`CHANGELOG.md`, `change-log.md`, docs, release notes).
- **Categorisation gap:** the form offers `Critical / High / Medium / Low` priority and a separate emergency procedure, but does not classify changes as **Standard / Normal / Emergency**. That distinction is needed for area 8's authority matrix. No `Change type` field, no requested-by / target-release fields.

**Actionable Fix**

1. Add to the top of `change_request.md`:
   `Change type: Standard (pre-approved, low risk) | Normal (CCB approval) | Emergency (CAB retro-approval within 1 working day)`,
   plus `Requested by`, `Target release`, `CAB/CCB decision ID`, `Rollback plan`, `Post-change verification plan`.
2. Update `change-management-process.md` §3 to route each type to the CCB/CAB authority matrix from area 8.
3. Require the completed form (or a link) in every PR touching `backend/src`, `frontend/lib`, `.github/workflows`, `render.yaml`, `docker-compose.yml`.

---

## 10. Post-Change Verification & Auditability

**Status: Partially Implemented**

**Findings**

- Post-deploy verification is automated and evidenced: `deploy-production.yml` triggers the exact CI-passed SHA, polls `/api/health` up to 10 minutes, runs `scripts/smoke-test.mjs` (3 checks: health 200, unauthenticated AI 401, unknown route 404), writes a deployment trace to the job summary, persists `LAST_GOOD_SHA`, and auto-rolls back on failure. `rollback.yml` repeats health + smoke after rollback. `RELEASE_EVIDENCE_v1.1.md` records run URLs, headers and results.
- Monitoring exists as code: `monitoring/` Prometheus rules, SLO burn-rate rules, Alertmanager example, Grafana dashboard; `docs/operations/MONITORING_RUNBOOK.md` and `POST_DEPLOYMENT_REVIEW.md` template.
- Audit trail exists through `change-log.md`, `CHANGELOG.md`, PR template checklist, release notes and tagged releases.
- **Gaps:** no CMDB/configuration-item register (only `DEPENDENCIES.md`, which is partly stale); alert delivery is a placeholder; no scheduled staging soak; manual NFR gates unevidenced; `POST_DEPLOYMENT_REVIEW.md` is an empty template — no filled review found.

**Actionable Fix**

1. Add `docs/operations/CMDB.md`: configuration items (Render services, MongoDB, domains, secrets variables, CI environments, tool versions), owner, environment, source of truth, change link, last verified date. Correct the stale lines in `DEPENDENCIES.md`.
2. Fill one `POST_DEPLOYMENT_REVIEW.md` per release with before/after error rate and p95 from Grafana, and link it from release evidence.
3. Wire a real Alertmanager receiver (Slack example is committed) and schedule the k6 soak; record the resulting SLO report as post-change monitoring evidence.

---

## Readiness score and priority actions

**SQA & Change Governance Readiness Score: 7.0 / 10**

Rationale: verification automation, test breadth, release evidence and rollback
engineering are unusually strong for an individual project (would score 8–9 on
those axes alone). The score is held down by four formal-governance gaps: no
RTM, no SQA defect metrics, no in-repo defect log, and no explicit CCB/CAB
authority — plus missing test-plan suspension criteria and thin independent
code review.

### Top 3 highest-priority improvements

1. **Build the RTM + test-case catalogue** (`docs/quality/RTM.md`,
   `docs/testing/TEST_CASE_CATALOGUE.md`) — closes areas 1 and 5 and makes every
   other audit claim traceable in one place.
2. **Stand up the defect log and SQA metrics** (`docs/quality/DEFECT_LOG.md`,
   `docs/quality/QUALITY_METRICS.md`) with DDE, defect density and escaped
   defects, backfilled from `git log` and Jira — closes areas 6 and 7.
3. **Formalise CCB vs CAB and review authority** (`GOVERNANCE.md`, approval
   environment reviewers, risk-tiered review policy) — closes areas 3, 8 and 9,
   and makes the production approval auditable rather than implicit.

> In parallel, fix the two documentation-drift defects found in this audit
> (`RELEASE_CHECKLIST.md` 60% → 62%; `DEPENDENCIES.md` bot statement) — they are
> small but directly undermine auditability.
