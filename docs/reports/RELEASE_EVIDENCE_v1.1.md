# Release Evidence — Auxilia v1.1

Release tag: `v1.1` → commit `b90d82b` ("test(qa): pact provider verification, visual regression, alert wiring (#110)")
GitHub release: <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/releases/tag/v1.1> (2026-11-19)
Base: previous release `v1.0.0` → `7827d9d` (2026-11-15)
Changelog: <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/compare/v1.0.0...v1.1>

This document supersedes the blank template at `docs/reports/RELEASE_EVIDENCE_v1.0.0.md`
for the current release line. All figures below were measured on 2026-11-19, not estimated.

## CI runs (all on `main`)

| Date (UTC) | Run | Title | Result |
|---|---|---|---|
| 2026-11-19T08:55Z | <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44491730340> | CI | **success** — 11/11 jobs green: Gitleaks, CodeQL, Trivy, Backend, Frontend, E2E (docker-compose + Playwright), Final Quality Gate, SonarCloud check-run, Dependency Review |
| 2026-11-19T08:55Z | <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44491730456> | SBOM & SLSA Provenance | success |
| 2026-11-19T09:12Z | <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44494233091> | Production Deployment | success (post-deploy smoke, Render) |
| 2026-11-19T09:12Z | <https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/actions/runs/44488063872> | Deploy pre-checks | success |

`CI - Final Quality Gate` on the v1.1 push run: **success** (the check required by the `main` branch protection rule).

## Pipeline gate evidence (v1.1 push run 44491730340)

| Job | Conclusion |
|---|---|
| Security - Gitleaks | success |
| Security - CodeQL | success |
| Security - Trivy | success |
| Backend - Quality & Build | success |
| Frontend - Quality & Build | success |
| E2E - Docker Compose + Playwright | success |
| CI - Final Quality Gate | success |
| Performance - API Latency & Error Budget | skipped (`workflow_dispatch` only, deliberately) |
| Dependencies - Review | skipped by repo variable at the time; **enabled 2026-11-19** (repo is now public; `DEPENDENCY_REVIEW_ENABLED=true`) |

## Runtime verification of the production deployment (2026-11-19)

`GET https://ay2627s2-cicdp-keefechen-1.onrender.com/api/health` → `200` with body `{"status":"ok","service":"personal-secretary-api"}`

Response headers (curl): `content-security-policy: default-src 'self' ...; frame-ancestors 'self'; object-src 'none'; upgrade-insecure-requests` · `strict-transport-security: max-age=15552000; includeSubDomains; preload` · `x-frame-options: SAMEORIGIN`

Post-deployment smoke test, run from a clean checkout on 2026-11-19:

```
$ node scripts/smoke-test.mjs https://ay2627s2-cicdp-keefechen-1.onrender.com
PASS GET /api/health returns 200
PASS POST /api/ai/chat without auth returns 401
PASS Unknown API route returns 404
Smoke test: 3/3 checks passed.
```

## Automated verification summary (2026-11-19, QA branch `feature/qa-level2-3-implementation` for measurements; v1.1 main carries the same suite)

| Check | Result |
|---|---|
| Backend vitest | **378 tests / 51 files** all passing |
| Backend coverage (v8) | 59.84 / 50.34 / 61.09 / 60.66 vs ratchet 58/48/59/58 ✓ |
| Backend contract layer | 3/3 (2 consumer + 1 provider verification) |
| Backend MongoDB-backed integration | 8/8 against a real in-memory mongod |
| Backend Stryker mutation | 100.00 (26/26 mutants killed; scope: `tokens.ts`, `AppError.ts`) |
| Frontend unit/widget | 330 tests passing |
| Frontend coverage gate | 62.5% ≥ 62% ✓ |
| Frontend visual goldens | 2 baselines (CI ubuntu gate; skipped on Windows/macOS locally) |
| Frontend accessibility (Flutter guidelines) | 3/3 — found & fixed 3 real WCAG AA defects (dark-mode auth form card) live |
| Frontend a11y (Playwright axe spec) | green in E2E job |
| Android emulator `flutter drive` | cold-start intro → login path passed (API 37; CI runs API 34) |

## Known limitations (honest)

- No `.trivyignore`; `.zap/rules.tsv` intentionally empty (baseline DAST only).
- Backend coverage excludes 3 modules pending tests (documented in `vitest.config.mts`).
- Mongo-backed tests cover the task module; other modules' model behaviour is mocked except at the E2E layer.
- Stryker scope is deliberately 2 critical files — does not imply mutation-proof codebase.
- `Performance - API Latency & Error Budget` is `workflow_dispatch`-only; no blocking SLO gate in CI (staging soak documented as future work).
- The `develop` branch protection requires `CI - Final Quality Gate` (enabled 2026-11-19); required approving reviews remain 0 by design (solo assessor project; admin bypass disabled on `main` via `enforce_admins`).
- SBOM/provenance attestation is published to the public repository's registry; SLSA attestation on the release itself was deferred when the repo was private and has not been re-cut for v1.1.

## Rollback

Production rollback path (`.github/workflows/rollback.yml`): re-deploys a chosen prior SHA via Render hook; prior release `v1.0.0` tag exists for rollback-to-tag. Health-poll + post-deploy smoke (`scripts/smoke-test.mjs`) gate the process; runbook at `docs/deployment/ROLLBACK_RUNBOOK.md`.
Recovery time objective: < 10 minutes (Render redeploy + health poll window).
