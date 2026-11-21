# CI Workflow — Enterprise 4-Stage Pipeline Notes

`.github/workflows/ci.yml` was refactored into a clean 4-column DAG. Only **`4 · Gate · CI Final Quality Gate`** needs to be a required check in Branch Protection.

## Required secrets and variables

| Name | Type | Where | Purpose | If missing |
|---|---|---|---|---|
| `SONAR_TOKEN` | Secret | Settings → Secrets → Actions | Authenticates the single SonarQube-family quality gate | Analysis step is skipped with a warning; the job stays green (needed for fork PRs where secrets are unavailable) |
| `SONAR_HOST_URL` | Variable (optional) | Settings → Variables → Actions | Sonar server URL; defaults to `https://sonarcloud.io` | Uses SonarCloud automatically |
| `CODE_SCANNING_ENABLED` | Variable (optional) | Settings → Variables → Actions | Set to `true` to enable SARIF upload on private repos with GHAS | CodeQL still analyzes; upload disabled |
| `RENDER_API_BASE_URL` | Variable | Settings → Variables → Actions | Used by `deploy-production.yml`, not by CI itself | Unrelated to this workflow |

No other secret is required by `ci.yml`. `GITHUB_TOKEN` is provided automatically by Actions.

**Note:** the old `DEPENDENCY_REVIEW_ENABLED` repo variable is no longer consulted — dependency review now runs on every PR as requested. You can leave the variable set; it is harmless.

## Cache strategy

| Cache | Mechanism |
|---|---|
| npm (backend, frontend releases? no npm in frontend, E2E) | `actions/setup-node` with `cache: npm` + `cache-dependency-path` |
| Flutter packages | `subosito/flutter-action` with `cache: true` |
| Docker layers | BuildKit GHA cache — `cache-from: type=gha,scope=backend|frontend`, `cache-to: type=gha,mode=max,...` |

There is **no Maven/Gradle build in this repository** (Flutter + Node/TypeScript only), so adding JVM caches would be dead configuration; none were added.

## Stage / job map

| Stage | Jobs | Runs on |
|---|---|---|
| 1 · Preflight & fast security | PR Conventions, Dependency Review (PR only); Gitleaks, CodeQL (all events) | push, PR, dispatch |
| 2 · Build, test & artifacts | Backend, Frontend (parallel) | all events; `if: always()` tolerates Stage 1 PR-only skips, but fails on any Stage 1 failure/cancelled |
| 3 · Deep quality & CVEs | SonarQube Quality Gate, Trivy image scan (parallel) | after both Stage 2 jobs succeed; Trivy consumes the image tarballs produced in Stage 2 (no registry/paid infra) |
| 4 · Integration & final gate | E2E + live performance smoke; Final Gate (`if: always()`) | after both Stage 3 jobs succeed; Final Gate aggregates all 9 jobs |

## Notes on the moved jobs

- **Trivy** now scans the exact backend/frontend images built in Stage 2, loaded from uploaded tar artifacts. It no longer builds images itself before compilation.
- **Performance** is no longer a standalone `workflow_dispatch` job. The E2E job runs a curl-based p95 probe against the live `/api/health` endpoint while the compose stack is up, then runs the repo's existing error-budget smoke (`npm run test:performance`). Containers are torn down in `if: always()`.
- **SonarCloud duplicate removed**: one job named `sonarqube-quality-gate` runs the scanner with `sonar.qualitygate.wait=true`, consuming the backend coverage artifact. `sonarqube-automatic` (the check-run poll) is gone.
- The Final Gate treats `skipped` as success only for the two PR-only jobs on non-PR events; any `failure`, `cancelled`, or unexpected `skipped` fails the gate.
