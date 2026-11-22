# Defect & Issue Log — Auxilia

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** QA / release owner
**Purpose:** single in-repository record of confirmed defects and their
resolution, including the fields needed for DDE, defect density and escaped
defect metrics ([QUALITY_METRICS.md](QUALITY_METRICS.md)).
**Relationship to GitHub/Jira:** GitHub Issues hold the live conversation;
this log holds the governance fields (severity, priority, reproducibility,
owner, target date, fix evidence, regression test, escaped flag). Entries marked
"backfill" were reconstructed from `git log`, investigation reports and release
evidence; exact dates were not recorded at the time and are shown as `TBD`
rather than invented.

**Status:** Open · In Review · Fixed · Closed · Won't fix (with reason).
**Reproducibility:** Always · Intermittent · Unknown.
**Escaped:** Y = found in production after release; N = found before release.

| ID | Title | Severity | Priority | Repro | Detected in | Owner | Target date | Status | Fix commit / PR | Regression test | Escaped | Closed date |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DEF-001 | AUX-85: Render startup crash — port not bound to 0.0.0.0, bind errors silent | Critical | Critical | Always | Production deploy (15 Nov) | Keefe Chen | 16 Nov 2026 | Closed | AUX-58 investigation; `server.on("error")` handler | health poll + smoke in `deploy-production.yml` | Y | 16 Nov 2026 |
| DEF-002 | AUX-84: Docker image build failure — production dependencies missing at runtime | High | High | Always | CI image build | Keefe Chen | 16 Nov 2026 | Closed | AUX-58 F-2 (baseline install corrected) | Trivy/image build in CI | N | 16 Nov 2026 |
| DEF-003 | Calendar routes validated identifiers but never enforced `validationResult` → 500 | High | High | Always | Code review / API test | Keefe Chen | TBD | Fixed | `d81bd7a`, `f0d4369` | `backend/tests/regression/known-issues.test.ts` | N | TBD |
| DEF-004 | Refresh-token replay did not revoke the session | High | High | Always | Security review | Keefe Chen | TBD | Fixed | `4c40f63` | `backend/tests/regression/known-issues.test.ts` | N | TBD |
| DEF-005 | Weak/common passwords accepted at signup | Medium | High | Always | QA | Keefe Chen | TBD | Fixed | password policy hardening | `backend/tests/regression/known-issues.test.ts` | N | TBD |
| DEF-006 | Rate limiting returned non-structured errors instead of 429 contract | Medium | Medium | Always | QA | Keefe Chen | TBD | Fixed | rate-limit hardening | `backend/tests/regression/known-issues.test.ts` | N | TBD |
| DEF-007 | CodeQL: log injection in `auth.service.ts` | High | High | Always | CI CodeQL (15 Nov) | Keefe Chen | 15 Nov 2026 | Fixed | `7afd00f` (Copilot Autofix, human reviewed) | auth integration tests | N | 15 Nov 2026 |
| DEF-008 | SonarCloud: `unsafe-inline` and wildcard sources in web CSP | High | High | Always | CI SonarCloud (PR #12) | Keefe Chen | 8 Nov 2026 | Fixed | PR #12 (`frontend/web/index.html`) | `e2e/tests/smoke.spec.ts` (CSP asserted) | N | 8 Nov 2026 |
| DEF-009 | CodeQL: polynomial regex (ReDoS) on user input in `ai.service.ts` | High | High | Always | CI CodeQL (PR #12) | Keefe Chen | 8 Nov 2026 | Fixed | PR #12 (`stripTrailing`, `extractCourse`) | `backend/tests/ai/ai-guardrails.test.ts` | N | 8 Nov 2026 |
| DEF-010 | Authenticated API routes lacked global baseline rate limiter | High | High | Always | CI CodeQL (PR #12) | Keefe Chen | 8 Nov 2026 | Fixed | PR #12 (`apiRateLimiter` on `/api`) | `backend/tests/integration/rateLimiterRedis.test.ts` | N | 8 Nov 2026 |
| DEF-011 | Pact consumer contract described a provider shape that never existed | High | High | Always | Pact provider verification (19 Nov) | Keefe Chen | 19 Nov 2026 | Fixed | `b90d82b` / PR #110 | `backend/tests/contract/*` (both halves in `npm test`) | N | 19 Nov 2026 |
| DEF-012 | Golden test suite deleted as "flaky" (f4e5976) — visual regression lost | Medium | Medium | Always | CI audit (19 Nov) | Keefe Chen | 19 Nov 2026 | Fixed | `9924c47`, `b90d82b` | `frontend/test/visual/golden_test.dart` (Linux-only gate) | N | 19 Nov 2026 |
| DEF-013 | AuthShell dark-mode contrast — 3 WCAG AA failures (~2.5:1) | Medium | High | Always | Flutter a11y guideline suite (19 Nov) | Keefe Chen | 19 Nov 2026 | Fixed | PR #113 (`auth_shell.dart`) | `frontend/test/accessibility/accessibility_test.dart` | N | 19 Nov 2026 |
| DEF-014 | Stryker 53.85% — surviving mutants in `verifyAccessToken` claim guards | Medium | Medium | Always | Mutation test (19 Nov) | Keefe Chen | 19 Nov 2026 | Fixed | 3 added unit tests | `backend/tests/unit/**` tokens tests | N | 19 Nov 2026 |
| DEF-015 | CI first-run authentication E2E failed before login screen | High | High | Always | CI E2E run 43700797701 (15 Nov) | Keefe Chen | 16 Nov 2026 | Closed | issue #69 fix | `e2e/tests/auth.spec.ts` | N | 16 Nov 2026 |
| DEF-016 | Development `JWT_SECRET` fallback reintroduced in `docker-compose.yml` (S2068) | Medium | Medium | Always | SonarCloud / AUX-175 (21 Nov) | Keefe Chen | TBD | Open | issue #125 (proposed) | Gitleaks + SonarCloud gate | N | — |
| DEF-017 | Two `User` Mongoose schemas registered under same model name | Medium | Medium | Always | Schema audit (12 Nov) | Keefe Chen | TBD | Open | — (known limitation) | schema validators accept union | N | — |
| DEF-018 | Groups/audit/roadmaps excluded from backend coverage ratchet | Medium | Medium | Always | QA audit | Keefe Chen | TBD | Open | BACKLOG-8 | controller/integration tests pending | N | — |
| DEF-019 | Stale coverage gate in `RELEASE_CHECKLIST.md` (60% vs enforced 62%) | Low | Low | Always | SQA audit (22 Nov) | Keefe Chen | 22 Nov 2026 | Fixed | 22 Nov doc fix | doc review | N | 22 Nov 2026 |
| DEF-020 | `DEPENDENCIES.md` claims no bot configuration though `dependabot.yml` exists | Low | Low | Always | SQA audit (22 Nov) | Keefe Chen | 22 Nov 2026 | Fixed | 22 Nov doc fix | doc review | N | 22 Nov 2026 |

## Backfill and maintenance rules

1. Every new defect gets an ID in this log in the same PR that fixes it, or on
   the day it is raised. Never leave a fix represented only by a commit message.
2. `Escaped = Y` defects require an incident note and a post-deployment review
   entry; they count against the release's DDE.
3. At each release, compute metrics per QUALITY_METRICS.md and append a summary
   row to that file. Escaped defects from the previous release are reviewed at
   the CAB meeting.
4. Export the external Jira board's open defects into this log at each sprint
   boundary so the in-repo record is complete.
5. Do not mark a defect Closed until the fix commit, regression test and
   verification result are all recorded.
