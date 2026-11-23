# Auxilia Master Test Plan

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** QA / release owner
**Applies to:** releases `v1.1+` and the current `main` line.
**Companion documents:** [TESTING_STRATEGY.md](TESTING_STRATEGY.md) (discipline
map), [MANUAL_TEST_PLAN.md](MANUAL_TEST_PLAN.md) (manual cases),
[TEST_CASE_CATALOGUE.md](TEST_CASE_CATALOGUE.md) (detailed cases),
[NFR_RELEASE_GATES.md](../compliance/NFR_RELEASE_GATES.md) (gates),
[RELEASE_CHECKLIST.md](../release/RELEASE_CHECKLIST.md) (release steps),
[QUALITY_METRICS.md](../quality/QUALITY_METRICS.md) (metrics).

## 1. Purpose and objectives

Define the scope, strategy, environment, criteria and deliverables for testing
each Auxilia release. Objectives: (a) prove functional correctness of the
Flutter client, Express API and their integration; (b) enforce non-functional
gates (security, accessibility, performance, privacy); (c) provide auditable
evidence for release decisions; (d) keep the coverage ratchets moving upward.

## 2. Release scope

**In scope:** Flutter web client and Android path; Express/TypeScript API;
MongoDB persistence; Docker Compose stack; Render deployment; CI/Jenkins
pipelines; documentation changes that affect behaviour or configuration.

**Out of scope this cycle:** iOS/macOS device farm (advisory workflow only),
live OpenAI-compatible provider and live SMTP delivery, OS-level notifications,
scheduled staging soak, external Jira board administration.

**Change control:** scope changes follow
[change-management-process.md](../change-management/change-management-process.md)
and [GOVERNANCE.md](../change-management/GOVERNANCE.md).

## 3. Schedule and milestones

| Phase | Typical timing | Exit |
|---|---|---|
| Impact assessment | On change request raised | CCB decision recorded |
| Development + local tests | Per sprint branch | PR opened with testing evidence |
| CI gates on PR | Every push/PR | `CI - Final Quality Gate` green |
| QA verification | Before tagging | Regression run + coverage gate green |
| Manual validation pass | Before tagging | Manual cases M-01…M-38 recorded |
| Release + deploy | Tag `v*.*.*` | Release workflow + smoke 3/3 green |
| Post-deployment review | Within 1 working day | Filled review + monitoring check |

Historical anchor dates: 27 Oct–15 Nov 2026 first delivery cycle;
v1.0.0 15 Nov; v1.1 19 Nov; QA verification 21 Nov; this plan 22 Nov.

## 4. Strategy

- **Verification** (build it right): static analysis, unit/integration/contract
  tests, coverage ratchets, security scanners, SonarCloud. Enforced by CI.
- **Validation** (build the right thing): user-story acceptance criteria, manual
  exploratory plan, end-user journeys in Playwright, demo script, production
  smoke and manual NFR gates.
- **Automation first:** every merged defect must have a regression test;
  automated suites run on every PR and are the blocking gate.
- **Environment/data:** see §5. **Toolchain:** Vitest, Supertest, Pact,
  mongodb-memory-server, Stryker, flutter_test, Playwright, axe-core, k6,
  Trivy, Gitleaks, CodeQL, SonarCloud, ZAP, Lighthouse.

## 5. Environment and test data

| Environment | Purpose | Notes |
|---|---|---|
| Local dev | Unit/widget tests | `npm ci`, `flutter pub get`; no DB required |
| In-memory test | Integration/functional | supertest + `mongodb-memory-server` (real mongod 8.x) |
| Docker Compose | E2E stack | `docker compose up -d --build`; API :3000, web :8080 |
| CI (`ubuntu-latest`) | Blocking gates | Flutter 3.47.8, Node 22; goldens run Linux-only |
| Render (production) | Post-deploy smoke | Non-mutating `scripts/smoke-test.mjs`; health poll 10 min |

Test data: `.env.example` for variables; `npm run seed:demo` provisions
demo accounts (refused in production unless `ALLOW_DEMO_SEED=true`); demo
credentials in `docs/admin/ADMINISTRATION.md`. Never use production user data
for testing.

## 6. Entry criteria

- [ ] Change request approved and CCB decision ID recorded (if scope/design affecting).
- [ ] Branch follows naming convention; PR template fully completed.
- [ ] Required CI checks green on the source branch (`CI - Final Quality Gate`).
- [ ] Target environment provisioned and reachable; `/api/health` returns 200.
- [ ] Test data seeded; demo accounts available; no open Critical defects.
- [ ] Test cases for the change added to [TEST_CASE_CATALOGUE.md](TEST_CASE_CATALOGUE.md).

## 7. Exit criteria

- [ ] All automated gates green: backend/frontend tests, coverage ratchets
      (58/48/59/58; **62%** frontend), build, lint/analyze/format.
- [ ] Pact consumer + provider verification both green; Mongo-backed suite green.
- [ ] E2E suite green on all 4 Playwright projects (documented skips excluded).
- [ ] Manual cases M-01…M-38 recorded with pass/fail and defect links.
- [ ] Security gates G8–G10 green; Trivy findings triaged; privacy impact reviewed.
- [ ] SQA metrics recorded: DDE, defect density, escaped defects (see QUALITY_METRICS.md).
- [ ] Smoke 3/3 green against the deployed environment.
- [ ] Documentation updated: RTM, change log, release evidence, post-deployment review.

## 8. Suspension and resume criteria

**Suspend testing when:**
- The environment is unavailable or `/api/health` fails for >10 minutes.
- More than 25% of the selected test cases fail in one run, or a run cannot be reproduced.
- A Critical defect is found (data loss, auth bypass, secret exposure, security gate red).
- Test data is corrupted or seed state cannot be reset.

**On suspension:** record the reason, affected cases and owner in the PR and
`DEFECT_LOG.md`; fix or obtain a documented waiver (security/privacy cannot be
waived). **Resume** when the blocking cause is closed, affected tests pass, and
the QA owner records the resume decision.

## 9. Deliverables

| Deliverable | Location |
|---|---|
| Test plan (this document) | `docs/testing/TEST_PLAN.md` |
| Test case catalogue with results | `docs/testing/TEST_CASE_CATALOGUE.md` |
| Automated test suites + coverage artifacts | `backend/tests/`, `frontend/test/`, CI artifacts |
| Regression run evidence | `docs/reports/REGRESSION_RUN_*.md` |
| QA verification record | `docs/reports/QA_VERIFICATION_*.md` |
| Release evidence + gate results | `docs/reports/RELEASE_EVIDENCE_*.md` |
| Post-deployment review | `docs/deployment/POST_DEPLOYMENT_REVIEW_*.md` |
| Defect log | `docs/quality/DEFECT_LOG.md` |
| SQA metrics | `docs/quality/QUALITY_METRICS.md` |

## 10. Risks and contingencies

| Risk | Contingency |
|---|---|
| Render free-tier cold start (~50 s) | Health poll up to 10 min; warm before demos |
| Golden tests platform-dependent | Linux-only gate in CI; do not regenerate without justification |
| Coverage ratchet red on new modules | Add tests, never lower thresholds (ADR required) |
| Manual gates unexecuted | Record as explicit residual risk in release evidence |
| External Jira board not in repo | Export board status into `DEFECT_LOG.md` each release |

## 11. Sign-off

| Role | Name | Date | Decision |
|---|---|---|---|
| QA owner | Keefe Chen | 22 Nov 2026 | Approved for v1.1+ |
| Release owner (CAB) | Keefe Chen | — | Per-release record |
| Reviewer | — | — | Optional independent reviewer per CODE_REVIEW_POLICY.md |
