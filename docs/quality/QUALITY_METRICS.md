# SQA Quality Metrics — Auxilia

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** QA / release owner
**Purpose:** make release-readiness measurable beyond "CI is green". Metrics
feed the Exit criteria of [TEST_PLAN.md](../testing/TEST_PLAN.md) and the
release evidence files.

## 1. Metrics definitions

| Metric | Formula | Source | Release threshold |
|---|---|---|---|
| Test pass rate | passed ÷ executed × 100 | CI test jobs / regression run | 100% of blocking suites |
| Test coverage (backend) | statements/branches/functions/lines from `backend/coverage/lcov.info` | `npm run test:coverage` | ≥ 58/48/59/58 (ratchet, never lower) |
| Test coverage (frontend) | lines covered ÷ total lines | `dart run tool/check_coverage.dart 62` | ≥ 62% |
| Mutation score | killed mutants ÷ total mutants × 100 | Stryker (`tokens.ts`, `AppError.ts`) | ≥ 60 break; 100 current |
| **Defect Density** | confirmed defects ÷ KLOC | `DEFECT_LOG.md` + `npx cloc . --exclude-dir=node_modules,build,coverage,dist` | track trend; no increase release-over-release without justification |
| **Defect Detection Efficiency (DDE)** | defects found before release ÷ (pre-release + post-release defects) × 100 | `DEFECT_LOG.md` (`Detected in` and `Escaped` fields) | ≥ 80% |
| **Escaped Defects** | defects discovered in production after release | `DEFECT_LOG.md` (`Escaped = Y`) | 0 Critical/High |
| Flaky test count | tests requiring a rerun to pass | CI reruns / issue log | 0 blocking |
| CI green rate | successful required runs ÷ total required runs in release window | GitHub Actions | ≥ 95% |

## 2. How to calculate (copy/paste)

```bash
# KLOC for defect density (development dependency, run from repo root)
npx cloc . --exclude-dir=node_modules,build,coverage,dist,.git --quiet

# Backend coverage
cd backend && npm run test:coverage

# Frontend coverage and gate
cd frontend && flutter test --coverage && dart run tool/check_coverage.dart 62

# Mutation score (advisory)
cd backend && npx stryker run
```

Then in `docs/quality/DEFECT_LOG.md` count rows by release for `Detected in` and
`Escaped`, apply the formulas above and write the result into the release table.

## 3. Measured values (historical anchor)

| Release | Backend cov (S/B/F/L) | Frontend cov | Tests | Mutation | DDE | Defect density | Escaped defects |
|---|---|---|---|---|---|---|---|
| v1.0.0 (15 Nov 2026) | 49.59/39.22/48.31/50.44 | 60%+ (gate then 60%) | 188 backend / 270 frontend (at report time) | not yet introduced | Not measured | Not measured | Not measured |
| v1.1 (19 Nov 2026) | 59.84/50.34/61.09/60.66 | 62.5% | 378 backend / 330 frontend | 100.00 (2 files) | Not measured | Not measured | Not measured |
| Current HEAD (21–22 Nov 2026) | see `QA_VERIFICATION_2026-11-21.md` | 62.5% | 378 / 330 (328 pass, 2 skip) | 100.00 | Not measured | Not measured | Not measured |

The three "Not measured" columns are the governance gap this file closes: from
the next release they are mandatory. Historical values are left as
"Not measured" rather than estimated — fabricating a number would be worse than
admitting it was not captured.

## 4. Release-readiness rule

A release is ready when **all** of the following hold:

1. All mandatory CI gates and coverage ratchets green.
2. DDE ≥ 80% and no open Critical/High defect (or a documented, approved waiver).
3. Zero escaped Critical/High defects from the previous release.
4. Defect density does not increase without an accepted justification.
5. Manual validation cases recorded; manual NFR gates either passed or listed
   as residual risk in the release evidence.

## 5. Ownership and cadence

- QA owner updates this table at each release gate and in the post-deployment review.
- Release owner reviews thresholds at each retrospective; threshold changes
  require an ADR (gates may be raised, never silently lowered).
- Raw data lives in `DEFECT_LOG.md`, `REGRESSION_RUN_*.md` and CI artifacts.
