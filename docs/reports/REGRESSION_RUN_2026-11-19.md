# Regression Run — 2026-11-19

**Branch / commit:** `feature/qa-contract-goldens-monitoring` @ `a0adecd` (+ this work) · **main:** `23e89ac` (PR #110 base)
**Why this artifact exists:** `docs/testing/TESTING_STRATEGY.md` requires that
every release carries a filled-in regression run rather than a blank evidence
template (`docs/reports/RELEASE_EVIDENCE_v1.0.0.md`). This is that run,
executed fresh on the QA branch on 2026-11-19. Counts below are measured,
not estimated.

## Environment

| | |
|---|---|
| OS | Windows 11 (25H2), x64 |
| Node | 22.14.0 |
| Flutter | 3.47.8 (channel stable) — same version pinned in CI |
| MongoDB | in-memory via `mongodb-memory-server` 11.x (real mongod 8.x binary) |
| Docker | not running during this run — compose stack not exercised locally; CI `e2e` job covers it |
| Android | emulator `Medium_Phone_API_37.0` (Android 17), real-device `flutter drive` run below |

## Results

| Suite | Result | Count |
|---|---|---|
| Backend vitest (all suites, `tests/**`) | ✅ pass | **51 files, 378 tests** |
| Backend coverage (v8, ratchet 58/48/59/58) | ✅ pass | 59.84 / 50.34 / 61.09 / 60.66 |
| Backend coverage artifact | uploaded (`backend-coverage`) | CI job |
| Backend contract layer (`npm run test:contract`) | ✅ pass | 3/3 (2 consumer + 1 provider verification) |
| Backend MongoDB-backed (`npm run test:mongodb`) | ✅ pass | 8/8 (real in-memory mongod: schema, pagination, CAS, soft-delete, ownership) |
| Backend regression pinning (`npm run test:regression`) | ✅ pass | 5/5 |
| Backend lint + typecheck (`npm run lint`) | ✅ pass | — |
| Stryker mutation (tokens.ts + AppError.ts) | ✅ pass | **100.00 score, 26 mutants killed, 0 survived, break ≥ 60** |
| Frontend unit/widget (`flutter test --coverage`) | ✅ pass | **330 tests** |
| Frontend coverage gate (`dart run tool/check_coverage.dart 62`) | ✅ pass | 62.5% ≥ 62 |
| Frontend visual regression (goldens) | ⚠️ CI-rendered | baselines are ubuntu-generated; suite **skips on Windows** — the CI `frontend` job is the gate |
| Frontend accessibility guidelines (`test/accessibility/`) | ✅ pass | 3/3 (TaskCard light; LoginScreen light & dark — dark mode caught 3 real WCAG AA defects, now fixed) |
| Frontend `dart format` / `flutter analyze --no-fatal-infos` | ✅ pass | — |
| Integration test on Android emulator (`flutter drive`) | ✅ pass | cold-start intro → login path passed on `Medium_Phone_API_37.0` |
| E2E (Playwright, 4 browsers, docker-compose stack) | ⏳ CI (`e2e` job) | — (not run locally: Docker Desktop not running) |
| Post-deploy smoke | ⏳ post-deploy only (`deploy-production.yml`) | — |

## Defects found and fixed during this run

1. **AuthShell dark-mode contrast (3 WCAG AA failures, ~2.5:1)** — the form
   card was hardcoded `AppColors.white` while its content used dark-theme
   text colors (near-white on white). Fixed: the card and the wide-layout
   panel are now theme-aware (`darkSurface` / `darkBorder` on the dark
   canvas).
2. **Pact consumer contract described a nonexistent provider shape** —
   corrected to `{ message, data }`, `_id`, `todo`; provider verification now
   runs in `npm test`.
3. **Golden suite f4e5976 deleted "flaky" test** — recreated with the flake
   sources eliminated; baseline refreshed for #98/#109 styling.
4. **Stryker 53.85% → 100%** — new unit tests kill the mutants that survived
   (claim type-guards in `verifyAccessToken`, AppError factories/defaults).

## Known limitations of this run

- E2E suite not re-executed locally (no Docker Desktop); CI runs it.
- Stryker scope deliberately small (2 critical files); do not read 100% as
  "the codebase is mutation-proof" — it means the critical auth primitives
  are.
- In-memory Mongo covers the task repository/model; other modules' model
  behaviour is still mocked everywhere except E2E.
- Android API 37 emulator; the CI integration workflow uses API 34.
