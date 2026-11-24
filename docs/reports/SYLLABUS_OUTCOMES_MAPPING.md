# ST0529 CA1 Syllabus → Repository Evidence Mapping

**Project:** Auxilia (offline-first academic task manager)
**Mapping date:** 22 November 2026
**Method:** static audit of the repository at `HEAD` (`78582a0`), cross-checked
against git history (280 commits, tags `v0.1.0` / `v1.0.0` / `v1.1`) and the
existing evidence reports. This document maps the 20 numbered sub-outcomes of
the Detailed Syllabus to concrete in-repo artefacts. It is deliberately honest:
statuses describe **evidence that a marker can open**, not aspiration.

**Status key**

| Status | Meaning |
|---|---|
| **Strong** | Multiple concrete artefacts; outcome clearly demonstrated. |
| **Partial** | Real evidence exists, but a named artifact or documented practice is missing. |
| **Gap** | Little or no in-repo evidence; external verification needed. |

---

## 1. Summary

| Outcome | Status | Headline evidence |
|---|---|---|
| **A — Project Management (1.1–1.5)** | **Partial → Strong** | Complete planning/story/change-control documentation and 3 shipped releases; no committed timeline visualisation (Gantt/burndown) and no exported board snapshot. |
| **B — Quality Assurance (2.1–2.5)** | **Strong** | 15 documented testing disciplines, 378 backend + 330 frontend tests, explicit EP/BVA/Use-Case design tests, coverage ratchets, Pact, Playwright, Stryker, axe, goldens. |
| **C — Integration & Delivery Pipeline (3.1–3.5)** | **Strong** | Git lifecycle with 4-prefix branching, 12-stage GitHub Actions pipeline + Jenkins parity, release/deploy/rollback workflows, documented log-driven failure diagnosis. |
| **D — Software Development & Deployment (4.1–4.5)** | **Strong (4.2 partial)** | Flutter + Express/TypeScript/MongoDB full stack, live Render deployment with health/smoke evidence; GenAI assistance is visible in git trailers but not documented as a practice. |

---

## 2. Outcome A — Project Management (0:0:22)

### 2.1 Sub-outcome mapping

| # | Requirement | Status | Evidence in this repository | Gap / note |
|---|---|---|---|---|
| 1.1 | Apply PM methodologies for timely delivery, resource optimisation, stakeholder satisfaction, sustainable approach | **Partial** | `docs/planning/PROJECT_PLAN.md` (vision, objectives, non-goals, phases, risk register, evaluation plan); `docs/planning/USER_STORIES.md` (personas, priorities, story points, Definition of Done); `docs/reports/RUBRIC_SELF_ASSESSMENT.md` (honest scoring and retrospective). Iterative delivery: tags `v0.1.0` → `v1.0.0` → `v1.1`. | Methodology is "Agile-inspired, solo delivery", never named as a formal framework. No measurable resource-optimisation or stakeholder-satisfaction data (the evaluation plan exists; results are not recorded). |
| 1.2 | Structured change control, smooth transitions, minimal disruption | **Strong** | `docs/change-management/change-management-process.md` (submit → evaluate → approve/reject/defer → implement → review → test → merge → document/close; emergency hotfix path; impact-assessment criteria); `docs/change-management/change-log.md`; root `CHANGELOG.md`; `.github/ISSUE_TEMPLATE/change_request.md`; `.github/pull_request_template.md`; protected `main`/`develop`; CI gates. | Board approvals live in GitHub Issues, not committed; solo project uses one person in four roles (documented openly). |
| 1.3 | Create project plans and schedules using PM tools | **Partial → Strong** | `docs/planning/PROJECT_PLAN.md` §§3, 8 (phase timeline with targets, status key), `docs/planning/TASKS.md` (phase-by-phase checklists), `docs/planning/USER_STORIES.md` (priorities, points, acceptance criteria), Jira keys `NP-*`/`AUX-*`/`BACKLOG-*` used for traceability. | The actual Jira board/schedule was external and is not exported into the repo; no Gantt chart or schedule file is committed. A screenshot of the board is referenced in `USER_STORY_CICD_REPORT.md` but not stored locally. |
| 1.4 | Use PM tools to monitor progress and visualise timelines | **Partial** | Progress monitoring evidence: `docs/reports/USER_STORY_CICD_REPORT.md` (story-by-story status table, CI run IDs #87–#101), `docs/reports/RELEASE_EVIDENCE_v1.1.md` (run URLs, gate results), `docs/reports/REGRESSION_RUN_2026-11-19.md`, coverage ratchets, `monitoring/` dashboards for runtime visualisation. | **Main PM gap:** no burndown chart, Gantt chart, roadmap timeline export, or board snapshot in the repository. Evidence is textual/status-table based; a marker cannot "see" a timeline. |
| 1.5 | Implement Agile practices to evolve and morph the project | **Strong** | `docs/planning/USER_STORIES.md` (standard story format, backlog with 12 catalogued items, explicit Definition of Done), `docs/planning/PROJECT_PLAN.md` status key (Implemented / Planned / Exploration / Deferred) and phase gates, iterative reprioritisation visible in git history and the v1.0.0→v1.1 re-scoring in `RUBRIC_SELF_ASSESSMENT.md`, scope recorded as changed rather than silently dropped. | No sprint ceremony artefacts (stand-up notes, retrospective minutes) beyond the assessment documents. |

### 2.2 What would close Outcome A's gaps

1. Commit a **project timeline artifact** (a simple Markdown/Gantt table or exported board view) to `docs/planning/` with dated phases and actual delivery dates — directly evidences 1.3 and 1.4.
2. Export or screenshot the Jira/GitHub board at a milestone into `docs/assets/` and link it from `USER_STORY_CICD_REPORT.md`.
3. Add one short **sprint retrospective** record (what changed, why, what was deferred) to `docs/planning/` to evidence 1.5/1.1 "evolve and morph".

---

## 3. Outcome B — Quality Assurance (0:0:23)

### 3.1 Sub-outcome mapping

| # | Requirement | Status | Evidence in this repository | Gap / note |
|---|---|---|---|---|
| 2.1 | Validation & verification methods for software quality assurance | **Strong** | `docs/testing/TESTING_STRATEGY.md` (15 disciplines; unit/integration/functional/regression/contract/security/performance/accessibility/visual/smoke/manual); `docs/compliance/NFR_RELEASE_GATES.md` (G1–Gx release gates); `docs/testing/MANUAL_TEST_PLAN.md` (9 sections); `docs/reports/QA_VERIFICATION_2026-11-21.md`; V&V split visible between verification gates (CI) and validation (E2E, manual plan, demo script). | Manual NFR gates (screen reader on device, 200% text scale on physical device, rollback rehearsal, DB backup) remain documented but unexecuted — stated in `RELEASE_EVIDENCE_v1.1.md`. |
| 2.2 | Testing techniques verify functionality and reliability | **Strong** | 378 backend tests / 51 files and 330 frontend tests (2026-11-19 measured); functional API journeys, MongoDB-backed tests (8/8 with real mongod), offline queue/conflict/retry tests, E2E on 4 browser projects (Chromium/Firefox/WebKit/Pixel 7), latency budget p95 < 500 ms, regression pinning (`known-issues.test.ts`). | iOS/macOS device coverage is advisory only; performance is `workflow_dispatch` only. |
| 2.3 | Test cases using design techniques (EP, BVA, Use Case, etc.) | **Strong (named, narrow)** | `backend/tests/unit/validators/task.query-design.test.ts` explicitly declares "Equivalence Partitioning (EP), Boundary Value Analysis (BVA), and Use Case Testing (UC)" with individually named cases (e.g. `BVA-upper boundary: limit=100`, `EP-invalid: negative page`). `backend/tests/unit/modules/users/user.validation.test.ts` uses equivalence partitioning. | Techniques are documented in **code comments only**; `TESTING_STRATEGY.md` and `MANUAL_TEST_PLAN.md` do not summarise them. Consider adding a short section to the strategy doc so a marker can find the evidence without opening test files. |
| 2.4 | Automated test scripts with frameworks and tools | **Strong** | Vitest + Supertest, flutter_test, Playwright, Pact JS V3 (consumer + provider), Stryker, axe-core, Flutter goldens, k6, `scripts/run-all-tests.mjs` orchestrator; each wired into `ci.yml` or its own workflow. See `docs/reports/TESTING_TOOLS_REPORT.md` for tool-by-tool rationale. | Backend coverage excludes groups/audit/roadmaps; Stryker scope is two files (both disclosed). |
| 2.5 | Update test scripts as features evolve | **Strong** | Pact consumer contract corrected when provider reality changed and provider verification added; visual goldens regenerated after the completed-card restyle (with PR justification rule); accessibility suite recreated and immediately fixed 3 real WCAG AA defects; regression rule "no bug closes without a regression test"; coverage ratchets raised, never lowered. | Some updates were reactive (drift found late); documented honestly in `TESTING_TOOLS_REPORT.md` §3. |

### 3.2 What would close Outcome B's gaps

1. Add a **"Test design techniques"** subsection to `docs/testing/TESTING_STRATEGY.md` linking the two files above (1 paragraph).
2. Execute and evidence at least one outstanding manual NFR gate (device text-scale or screen-reader pass) before submission.

---

## 4. Outcome C — Integration and Delivery Pipeline (0:0:23)

### 4.1 Sub-outcome mapping

| # | Requirement | Status | Evidence in this repository | Gap / note |
|---|---|---|---|---|
| 3.1 | Use Git to manage project lifecycle | **Strong** | 280 commits, 3 release tags, active `main`/`develop`, ~dozens of short-lived branches, PR-based merges, Conventional Commits, protected branches, `CODEOWNERS`, `dependabot.yml`, PR template. Verified locally with `git log`, `git branch -a`, `git tag -l`. | None material. |
| 3.2 | Branching strategies for collaborative development and delivery | **Strong** | `docs/release/BRANCHING.md` defines `feature/`, `bugfix/`, `hotfix/`, `refactor/` (+ `release/`, bot exemptions); enforced by the `pr-conventions` CI job (`.github/scripts/check-branch-name.mjs`); one-branch-one-issue rule; `hotfix/` is the visible emergency lane. | Latest commit `78582a0` adds acceptance of generated bot branch names — strategy is being actively maintained. |
| 3.3 | Construct integration & delivery pipeline for build/test/delivery | **Strong** | `.github/workflows/ci.yml` (staged jobs: dependency review, conventions, Trivy, gitleaks, CodeQL, backend, frontend, E2E, performance, SonarCloud, `ci-summary` aggregate gate); `Jenkinsfile` + `jenkins/Dockerfile` for local parity; `release.yml` (version verification, packaging, provenance attestation); `deploy-production.yml` (Render hook + health poll + smoke); `promote.yml`, `rollback.yml`, `sbom.yml`, `dast.yml`, `lighthouse.yml`, `approval.yml`; `docker-compose.yml` and `render.yaml` as code. | Evidence docs were last refreshed 19 Nov; a 4-stage pipeline refactor landed 21 Nov (`f4df71d`). Re-run and re-attach a green CI run so evidence matches current `HEAD`. |
| 3.4 | Automated testing inside the pipeline | **Strong** | `backend` job runs typecheck/lint/tests/coverage/build; `frontend` runs format/analyze/tests + 62% gate/web build; `e2e` builds the compose stack and runs Playwright across 4 projects; Pact both halves run in `npm test`; SonarCloud + Trivy + Gitleaks + CodeQL + dependency review; single required `CI - Final Quality Gate`. Ratchets cannot be lowered silently. | Manual/optional jobs (performance, Stryker, Android integration) are advisory by design — disclosed. |
| 3.5 | Analyse pipeline logs and test results to diagnose build/delivery failures | **Strong** | `docs/reports/USER_STORY_CICD_REPORT.md` §"CI quality-gate remediation" walks through individual failing CI runs (#87–#101) and root causes (Trivy base-image findings, SonarCloud "Security Rating on New Code < A" located via API, CodeQL ReDoS in `ai.service.ts`, CSP wildcards, missing baseline rate limiter); `docs/reports/AUX-58-DOCKER-RENDER-INVESTIGATION.md` diagnoses startup crash (`EADDRINUSE`/silent logging → port binding fix) and Docker production-dependency build failure; `AUX-57`, `AUX-175`, `AUX-178` repeat the pattern for integration, secrets, latency; Stryker survivor analysis and a11y defect diagnosis in `TESTING_TOOLS_REPORT.md` §3. | Raw log extracts are summarised rather than attached; CI run URLs exist in `RELEASE_EVIDENCE_v1.1.md` for verification. |

### 4.2 What would close Outcome C's gaps

1. Trigger one fresh CI + deploy run on current `HEAD` and append its URL/result to `RELEASE_EVIDENCE_v1.1.md` (or a v1.2 evidence file) — aligns evidence with the 4-stage pipeline now in the repo.
2. Attach one short log excerpt of a diagnosed failure beside its root-cause write-up (e.g. in `AUX-58-...md`) to make 3.5 immediately visible.

---

## 5. Outcome D — Software Development and Deployment (0:0:22)

### 5.1 Sub-outcome mapping

| # | Requirement | Status | Evidence in this repository | Gap / note |
|---|---|---|---|---|
| 4.1 | Languages, libraries, frameworks, tools for full-stack features | **Strong** | `frontend/` Flutter + Dart 3.13 (Riverpod, Material 3, responsive shell, offline-first stores, design system); `backend/` Express 5 + TypeScript strict (JWT, bcrypt, Zod, Mongoose, rate limiting, TOTP, RBAC, audit, Pact, Prometheus); MongoDB; Docker/nginx. API surface documented in `README.md` and `docs/architecture/`. | None material. |
| 4.2 | Develop full-stack features **and tests with generative AI assistance** | **Partial** | Git trailers are the concrete evidence: `7afd00f` "Potential fix for pull request finding 'CodeQL / Log injection'" and `81c0b86` / `3cec943` carry `Co-authored-by: Copilot Autofix powered by AI` — AI-generated, human-reviewed changes to backend code. A `codex/fix-pr-12` branch also exists. The AI assistant feature itself (`modules/ai/`, AI guardrail tests) evidences AI integration but is a product feature, not development assistance. | **Weakest sub-outcome.** No document records prompts, tools, or how AI assistance was reviewed/verified. Add a short "Generative AI assistance" section to `docs/development/` or `CONTRIBUTING.md` naming the tool(s), 2–3 example commits/files, and the review rule (AI output is always reviewed and covered by tests) to convert this to Strong. |
| 4.3 | Automated testing tools validate code before deployment | **Strong** | Every PR must pass the aggregate gate before merge; `release.yml` reruns all gates from clean installs before publishing; `deploy-production.yml` waits for `/api/health` and runs `scripts/smoke-test.mjs` (3/3 pass recorded); no direct pushes to `main`. | None material. |
| 4.4 | Provision cloud resources to deploy and host the application | **Strong** | `render.yaml` provisions two Singapore free web services (backend Docker + Flutter web/nginx) with declared health checks, `autoDeploy`, secret variables as `sync: false`, and explicit setup instructions; `docker-compose.yml` mirrors the stack locally; live URLs and secrets contract in `README.md`; deployment verified in `RELEASE_EVIDENCE_v1.1.md` (health 200, CSP/HSTS/frame-options headers, smoke 3/3). | Production is free tier (cold starts ~50 s) — a demo risk, not an outcome gap. |
| 4.5 | Configure hosting platform to execute and run the application | **Strong** | `render.yaml` + `frontend/nginx.conf` + `backend/Dockerfile` (non-root, npm/npx removed, digest-pinned base, `PORT` injected by Render); fix for the Render startup crash documented in `AUX-58`; `docs/deployment/RENDER_FRONTEND.md`, `POST_DEPLOYMENT_REVIEW.md`, `ROLLBACK_RUNBOOK.md`; observed live `/api/health` and strict CSP in release evidence. | Rollback rehearsal on production still unevidenced (a manual gate, not a configuration gap). |

### 5.2 What would close Outcome D's gaps

1. Document generative-AI-assisted development practice with commit pointers (converts 4.2 from Partial to Strong).
2. Re-verify the deployed web + API pair on current `HEAD` and record the result (keeps 4.4/4.5 evidence current).

---

## 6. Priority actions for a submission

| Priority | Action | Outcomes improved |
|---|---|---|
| High | Add a Generative AI assistance note with commit/PR pointers | 4.2 |
| High | Commit a dated timeline / board snapshot under `docs/planning/` | 1.3, 1.4 |
| Medium | Re-run CI + deploy on current `HEAD`; append fresh run URLs | 3.3, 3.5, 4.4, 4.5 |
| Medium | Add a short test-design-techniques subsection to `TESTING_STRATEGY.md` | 2.3 |
| Low | Execute one outstanding manual NFR gate and evidence it | 2.1, 4.5 |
| Low | Add one sprint retrospective / "what changed and why" record | 1.1, 1.5 |

---

## 7. Evidence index (open these first)

| Question | File |
|---|---|
| What is being built and why? | `README.md`, `docs/planning/PROJECT_PLAN.md` |
| What stories, priorities, Definition of Done? | `docs/planning/USER_STORIES.md` |
| How are changes controlled? | `docs/change-management/change-management-process.md`, `docs/change-management/change-log.md` |
| How is quality assured? | `docs/testing/TESTING_STRATEGY.md`, `docs/reports/TESTING_TOOLS_REPORT.md`, `docs/testing/MANUAL_TEST_PLAN.md` |
| What do the tests actually cover? | `backend/tests/`, `frontend/test/`, `e2e/tests/` |
| How does the pipeline work? | `.github/workflows/ci.yml`, `Jenkinsfile`, `docs/development/jenkins.md` |
| Was anything actually shipped? | `docs/reports/RELEASE_EVIDENCE_v1.1.md`, `docs/reports/REGRESSION_RUN_2026-11-19.md`, `docs/reports/USER_STORY_CICD_REPORT.md` |
| Where is it hosted? | `render.yaml`, `docker-compose.yml`, `docs/deployment/` |
| Overall honest assessment | `docs/reports/RUBRIC_SELF_ASSESSMENT.md` (v1.1 re-scored section) |

> **Note on currency:** the majority of the evidence reports were last refreshed on
> 19 November 2026, while the pipeline was refactored into a 4-stage flow on
> 21 November (`f4df71d`) and the MongoDB model extended on the same date
> (`729b93b`). The mapping above is based on what is committed now; a fresh CI
> run is recommended before submission so the documented evidence and the
> repository state agree.
