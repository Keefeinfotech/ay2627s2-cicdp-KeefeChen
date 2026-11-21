# QA Verification — 21 November 2026

Branch: `main` (`87db222`). Toolchain: Node 22.14.0, Flutter 3.47.8 / Dart 3.13.7.
Dependencies installed from the committed lockfiles with `npm ci --ignore-scripts`
and Flutter's dependency resolution during `flutter test`.

## Results

| Command | Result |
|---|---|
| `cd backend && npm ci --ignore-scripts` | 842 packages installed |
| `cd backend && npm run test:coverage` | **51 files passed, 378 tests passed** (unit, integration, MongoDB-backed, functional, contract, security, regression, AI) |
| `cd frontend && flutter test --coverage` | **330 tests (328 passed, 2 skipped)** — includes WCAG accessibility suite and golden tests |
| `cd frontend && dart run tool/check_coverage.dart 62` | **62.5% line coverage (7861/12571)** — gate 62% → PASS |

Backend coverage from the regenerated `backend/coverage/lcov.info`:

| Metric | Measured | Ratchet (`backend/vitest.config.mts`) | Result |
|---|---:|---:|---|
| Statements | 59.84% | 58% | PASS |
| Branches | 50.34% | 48% | PASS |
| Functions | 61.09% | 59% | PASS |
| Lines | 60.66% | 58% | PASS |

These figures match `docs/testing/TESTING_STRATEGY.md` and
`docs/reports/TESTING_TOOLS_REPORT.md`. The earlier discrepancy (51.48% lines)
was caused by a stale `node_modules`/coverage artifact on an older feature branch,
not by a red gate.

## Gate consistency fix

The frontend coverage gate was 62% in `.github/workflows/ci.yml` but 60% in the
`Jenkinsfile`, `README.md` and `NFR_RELEASE_GATES.md`; the documented backend
ratchet (49/39/48/50) was also older than the enforced one (58/48/59/58). All
documents and the Jenkins stage now use the values actually enforced by CI.

## Note

Pact provider verification rewrites `backend/pacts/Auxilia-Frontend-Auxilia-API.json`
metadata on each run; the generated change was reverted so the working tree stays clean.
