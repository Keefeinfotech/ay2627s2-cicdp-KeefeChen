# Change Management Process

This document defines how Auxilia proposes, evaluates, approves, implements,
tests, merges, documents and closes changes. It is deliberately lightweight:
it integrates with the GitHub-based workflow the project already uses
(GitHub Issues, pull requests, GitHub Actions) rather than adding external
tooling. It is written for a solo-developed project — the project owner is
both the requester and the approver — while remaining traceable enough to
satisfy a professional change-control audit.

## Purpose and scope

Change management controls **any deliberate modification** to:

- Requirements and user stories (`docs/planning/USER_STORIES.md`, tickets)
- Application features and source code (frontend and backend)
- Database schemas (MongoDB/Mongoose, Drift/SQLite local schema, migrations, backfills)
- API contracts (Zod schemas, routes, OpenAPI, Pact contract tests)
- System configuration (environment variables, Docker, GitHub Actions, Render)
- Security posture (auth, authorisation, middleware)

It applies to everything merged into `main` (protected by ruleset) and
`develop`. Trivial, reversible edits (typo fixes in docs, formatting) may use
the normal PR flow without a change request, but still go through a PR with
CI. Nothing described here bypasses CI, protected branches or the release
checklist in [docs/release/RELEASE_CHECKLIST.md](../release/RELEASE_CHECKLIST.md).

## Roles

| Role | Who | Responsibilities |
|---|---|---|
| Requester | Anyone (usually the owner) | Files the change request with enough detail to evaluate |
| Evaluator / Approver | Project owner | Assesses impact, accepts / rejects / defers before implementation |
| Implementer | Project owner or contributor | Cuts branch, implements, links the issue, keeps scope tight |
| Verifier | CI + the owner | Automated gates must pass; owner reviews the diff against the issue |

For a solo project these are one person wearing four hats. The process exists
so decisions are **written down and linked**, not to introduce ceremony.

## Change lifecycle

```text
Submit (GitHub Issue)                      Evaluate
┌────────────────────────┐                ┌──────────────────────────────┐
│ .github/ISSUE_TEMPLATE │── file issue ─▶│ Impact assessment            │
│   change_request.md    │                │ necessity / complexity / risk │
└────────────────────────┘                └─────────────┬────────────────┘
                                                        │
                                      Approve / Reject / Defer (comment on issue)
                                                        │
                                                        ▼
┌────────────────────────┐   implement   ┌──────────────────────────────┐
│ Change log + changelog │◀── document ──│ Branch (feature/… bugfix/…)  │
│ docs/change-management/│               │ PR → CI gates → review       │
│ change-log.md          │               │ Merge → close issue          │
└────────────────────────┘               └──────────────────────────────┘
```

### 1. Submit

Record the proposed change as a **GitHub Issue** using one of the templates in
`.github/ISSUE_TEMPLATE/`:

| Template | Use for |
|---|---|
| `change_request.md` | Non-trivial changes to requirements, code, schema, API, config |
| `feature_request.md` | Small enhancements (link a `change_request` if the impact is broad) |
| `bug_report.md` | Defects |

The change request must capture: description, reason/justification, proposed
implementation, impact assessment, priority (Critical / High / Medium / Low),
risks and mitigation, acceptance criteria and related issues or requirements.

### 2. Evaluate

Before any implementation work starts, assess:

- **Necessity** — does it serve the project scope or a real defect?
- **Complexity** — size, touched layers, unknowns.
- **Risk** — what can break, and how badly?
- **Impact on scope** — does it expand the milestone or contract?

Impact is assessed per area (see [Impact assessment criteria](#impact-assessment-criteria)).
Record the assessment in the issue (table is built into the template).

### 3. Approve, reject or defer

The approver decision is **a comment on the issue**, using this wording:

- `approved: implement now` — may proceed to step 4.
- `approved: schedule for <milestone/release>` — labelled and parked.
- `rejected: <reason>` — issue closed with the reason recorded; no code is written.
- `deferred: <reason and revisit date>` — issue left open, revisit later.

No issue, no code. The only exception is the
[emergency bug-fix procedure](#emergency-bug-fix-procedure).

### 4. Implement

Cut a branch from the current integration branch following
[docs/release/BRANCHING.md](../release/BRANCHING.md) — CI enforces the prefix:

- `feature/<slug>` — new functionality
- `bugfix/<slug>` — defect corrections
- `hotfix/<slug>` — emergency production fixes (see below)
- `refactor/<slug>` — behaviour-preserving maintenance
- `release/<x.y.z>` — release preparation

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `perf:`). One
branch = one issue.

### 5. Review

Open a pull request using `.github/pull_request_template.md`. It must:

- Link the issue (`Closes #<issue-number>`) so merging auto-closes it.
- Describe the reason, implementation, impact assessment and security
  considerations.
- Show the testing performed with commands and output.
- List regression risks and documentation updates.

A solo maintainer self-reviews the diff against the issue before merging; an
external reviewer is welcome but not required. The `main` ruleset already
requires a pull request and blocks direct pushes and deletions.

### 6. Test

CI (`.github/workflows/ci.yml`) runs on pull requests to `main`, `develop` and
`release/**` (docs-only changes under `docs/**`, `README.md`, `LICENSE`,
`CONTRIBUTING.md` are skipped via `paths-ignore`):

1. Dependency Review (fails on high-severity vulnerable dependencies)
2. PR Conventions (Conventional Commit title + branch name gate)
3. Security — Trivy (filesystem + container image) and Gitleaks
4. CodeQL static analysis
5. Backend — audit, lint, tests with coverage thresholds, build
6. Frontend — `pub get --enforce-lockfile`, format, analyze, tests + 60%
   coverage gate, web build
7. E2E — Docker Compose + Playwright
8. SonarCloud quality gate
9. CI — Final Quality Gate (aggregate)

All required checks must pass before merge. **High-impact areas require
additional regression testing** (not just green CI):

| Area | Extra verification |
|---|---|
| Authentication / authorisation (JWT, MFA, middleware) | Re-run backend security and functional suites; verify login/logout, session sign-out, `POST /api/ai/chat` 401 unauthenticated; manual smoke test |
| Database changes (Mongoose schema, indexes, backfill) | Validate against Atlas staging first; `npm run validate:collections`; confirm `/api/health` after deploy; back up before migration |
| API contracts (Zod, routes, OpenAPI, Pact) | Run `npm run test:contract` (Pact) and update provider/consumer pacts if the contract changed |
| Synchronisation (offline queue, conflict resolution) | Offline-online e2e scenario; backend change-feed compatibility; Drift migration test |
| Deployment configuration (Docker, Actions, Render) | Trigger deploy on a staging service or a branch deploy; smoke-test the deployed URL |

### 7. Merge

Merge only when:

- All required checks are green (including SonarCloud and the Final Quality Gate).
- The branch is up to date with its base branch.
- The PR description shows evidence the acceptance criteria were met.
- No unresolved review threads.

Use **squash** or **merge** commit (both allowed by the rulesets). `main` and
`develop` are never pushed to directly (blocked by the `Protect main branch` /
`Protect develop branch` rulesets).

### 8. Document and close

- Update `CHANGELOG.md` under `[Unreleased]` (meaningful, user-facing or
  system-level changes; categories: Added / Changed / Fixed / Security /
  Deprecated / Removed).
- Add a row to [`change-log.md`](./change-log.md) for significant changes.
- The linked issue closes automatically via `Closes #…`; if it was not
  auto-closed, close it referencing the PR.
- Tag milestones with a release; the release workflow and
  [`docs/release/RELEASE_CHECKLIST.md`](../release/RELEASE_CHECKLIST.md) take
  over from there.

## Impact assessment criteria

| Area | Questions to answer | Typical evidence |
|---|---|---|
| Requirements | Does it change scope, acceptance criteria or NFRs? | Updated user story in `docs/planning/USER_STORIES.md` |
| Architecture | Which layers are touched? New dependencies? | Architecture note in the issue/PR |
| Security | New inputs, permissions, data, secrets, or trust boundaries? | Security impact section in the issue/PR; Trivy/Gitleaks/CodeQL green |
| Database | Schema/index changes? Backfill? Backward compatible? | Migration notes; `validate:collections` output |
| API contract | Zod/route changes? Clients affected? | Pact contract test results; OpenAPI diff |
| Testing | Which suites are affected? New tests needed? | CI run; coverage delta |
| Deployment / CI-CD | New env vars, ports, volumes, workflow triggers? | Deploy dry-run; `render.yaml` diff; smoke test |
| Timeline | Estimate, dependencies, deadline risk | Milestone assignment |

Rating guide: **none** = untouched · **low** = internal, no contract impact ·
**medium** = cross-module, backward compatible · **high** = contract/migration/
security/deployment impact. Any **high** forces the extra verification listed
in [step 6](#6-test).

## Emergency bug-fix procedure

For a production defect that needs an immediate fix:

1. File a `bug_report.md` with severity **Critical** or **High** (this is the
   change record; it can be terse but must exist).
2. Cut `hotfix/<slug>` from `main`. Keep the diff minimal — fix only the defect.
3. Fast-track: implement, run the security + backend test suites locally, open
   the PR with `Closes #…`. **Do not skip CI.** A failing gate still blocks.
4. Merge when gates pass; verify deployment via the smoke test
   (`node scripts/smoke-test.mjs <base-url>`) and `/api/health`.
5. **Within one working day:** update `CHANGELOG.md` and `change-log.md`, attach
   the PR to the issue, and check whether the defect class needs an extra test
   to prevent recurrence. File a follow-up issue if the root cause is structural.
6. Merge `main` back into `develop`/active branches the same day.

## Change closure and documentation requirements

A change is **closed** when all of the following hold:

- [ ] Acceptance criteria met and evidenced in the PR (tests/output).
- [ ] Issue closed with a link to the merged PR.
- [ ] `CHANGELOG.md` updated (or explicitly marked not applicable in the PR).
- [ ] `change-log.md` updated for significant changes.
- [ ] Documentation touched (`README.md`, `docs/**`) when behaviour, contracts or
      configuration changed.
- [ ] Release notes (for tagged releases) reflect the change.

## Auxilia-specific impact areas

Any change touching the following must treat security, data integrity and
regression risk as non-trivial:

**Frontend** — Flutter/Dart, Riverpod state management, GoRouter navigation,
Drift + SQLite local persistence, offline-first sync queue. UI changes: 200%
text scale and light/dark screenshots in the PR. Schema changes to the local
Drift database require a migration and a sync-compatibility check.

**Backend** — Express.js + TypeScript, controller-service-repository
architecture, MongoDB Atlas + Mongoose, Zod validation and route contracts,
JWT authentication with security middleware (helmet, CORS, rate limiting,
CAPTCHA). Schema changes must be backward compatible or ship with a migration;
index changes ship with verification.

**DevOps / CI/CD** — Docker (backend multi-stage build), GitHub Actions
(CI, release, rollback, deploy-production, promotion, Lighthouse, DAST),
SonarCloud quality gate, Trivy + Gitleaks + CodeQL, Pact contract testing,
Render deployment (`render.yaml`). Configuration changes to any of these are
production-affecting and need a deploy smoke test before closing.

## CI/CD integration

Existing workflows already enforce the important gates (see
[step 6](#6-test)); no additional workflow is required and none should be
duplicated. Documentation-only changes under `docs/**` intentionally skip CI
via `paths-ignore` in `ci.yml`. Deployment approval stays with the
`Production Deployment` workflow (push to `main` → Render auto-deploy →
`/api/health` wait → smoke checks).

## Repository files vs GitHub settings

Implemented in the repository (this PR):

- Issue templates (`.github/ISSUE_TEMPLATE/`), PR template, `config.yml`
- This document and `docs/change-management/change-log.md`
- `CHANGELOG.md` structure and entries
- Branch naming enforced by `.github/scripts/check-branch-name.mjs` via CI

Manual GitHub configuration (cannot be done from repository files) — see the
list in the change-management rollout notes or `SECURITY.md`/repo settings:

1. **`main` ruleset** (`Protect main branch`): add the required status check
   `CI - Final Quality Gate` (and optionally `Code Quality - SonarCloud
   Automatic Analysis`) so merges block on green. Currently the ruleset only
   requires a PR (0 approvals) and blocks deletion/force-push.
2. **`develop` ruleset** (`Protect develop branch`): its `required_status_checks`
   list is empty; add the same checks. Also for PRs to `develop` they should
   match the PR targets already present.
3. **Environments**: the `production` environment variable
   `RENDER_API_BASE_URL` must point at the live service
   (`https://ay2627s2-cicdp-keefechen-1.onrender.com`, fixed 2026-11-16);
   optional `RENDER_DEPLOY_HOOK_URL` secret lets the deploy workflow trigger
   Render explicitly.
4. **Labels**: the `change-request` label used by the template was created;
   optionally add `priority: critical|high|medium|low` if you want label-based
   triage.
5. **Delete branch on merge**: enable in Settings → General → Pull Requests so
   merged `feature/*`/`bugfix/*` branches are auto-cleaned.

## Related documents

- [BRANCHING.md](../release/BRANCHING.md) — branch naming
- [RELEASE_CHECKLIST.md](../release/RELEASE_CHECKLIST.md) — release gates
- [RELEASE_NOTES_v1.0.0.md](../release/RELEASE_NOTES_v1.0.0.md) — release record
- [TESTING_STRATEGY.md](../testing/TESTING_STRATEGY.md) — test suites
- [CONTRIBUTING.md](../../CONTRIBUTING.md) — setup and PR expectations
- [SECURITY.md](../../SECURITY.md) — reporting vulnerabilities
- [CHANGELOG.md](../../CHANGELOG.md) — user-facing change history
