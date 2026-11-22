# Configuration Management Database (CMDB) — Auxilia

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** Release owner
**Purpose:** record the configuration items that make up the deployed system,
their source of truth and their change history. **No secret values are stored
here — only variable names and where their values live.**

## 1. Configuration items

| CI ID | Item | Environment | Version / value source | Owner | Source of truth | Last verified | Change reference |
|---|---|---|---|---|---|---|---|
| CI-01 | `auxilia-backend` web service | Render production (Singapore, free) | `render.yaml` + Docker image from commit SHA | Release owner | `render.yaml`, Render dashboard | 19 Nov 2026 | v1.1, deploy run 44494233091 |
| CI-02 | `auxilia-web` web service | Render production (Singapore, free) | `render.yaml`, `frontend/Dockerfile`, `API_BASE_URL` build arg | Release owner | `render.yaml`, Render dashboard | 19 Nov 2026 | v1.1, PR #117 |
| CI-03 | MongoDB (Atlas) | Production | `MONGODB_URI` (dashboard-injected) | Release owner | Render secret / Atlas | 19 Nov 2026 | `$jsonSchema` validators applied 12 Nov |
| CI-04 | Flutter toolchain | CI + local | Flutter 3.47.8 / Dart 3.13.x | DevOps | `ci.yml`, `jenkins/Dockerfile` | 21 Nov 2026 | pinned in CI |
| CI-05 | Node.js toolchain | CI + local | Node ≥ 22.12 (CI uses 22) | DevOps | `package.json` engines, `ci.yml` | 21 Nov 2026 | — |
| CI-06 | GitHub Actions workflows | GitHub | `ci.yml`, `release.yml`, `deploy-production.yml`, `rollback.yml`, `promote.yml`, `sbom.yml`, `dast.yml`, `lighthouse.yml`, `mutation.yml`, `integration.yml`, `approval.yml` | DevOps | `.github/workflows/` | 21 Nov 2026 | 4-stage refactor `f4df71d` |
| CI-07 | Jenkins server | Local | Jenkins LTS + JDK 21 + Node 22.14 + Flutter 3.47.8 | DevOps | `jenkins/Dockerfile`, `Jenkinsfile` | 16 Nov 2026 | — |
| CI-08 | GitHub Environments | GitHub | `production`, `approval` (required reviewers to be configured) | Release owner | GitHub Settings → Environments | 22 Nov 2026 | `RENDER_API_BASE_URL` fixed 16 Nov |
| CI-09 | Secrets (names only) | Render/GitHub | `JWT_SECRET`, `MONGODB_URI`, `TURNSTILE_SECRET_KEY`, `SMTP_*`, `AI_API_KEY`, `RENDER_API_KEY` | Release owner | Render dashboard / GitHub Secrets | 21 Nov 2026 | issue #125 (JWT fallback removal) |
| CI-10 | Observability stack | Local compose profile | Prometheus, Alertmanager, Grafana, SLO rules | DevOps | `monitoring/`, `docker-compose.yml` | 19 Nov 2026 | PR #113 |
| CI-11 | Dependency automation | GitHub | Dependabot (npm, pub, github-actions) | DevOps | `.github/dependabot.yml` | 22 Nov 2026 | active PRs #132–#138 |
| CI-12 | Public endpoints | Production | API `<render-api-host>/api/health`; web `https://auxilia-web.onrender.com` | Release owner | `README.md`, release evidence | 19 Nov 2026 | v1.1 |

## 2. Change rules

1. Any change to an item above requires a PR and a `CCB-*` decision if it
   alters configuration, plus a `CAB-*` decision for production deployment.
2. Update this CMDB in the same PR: version/source, last verified date and
   change reference.
3. Secrets are never stored here. If a variable name changes, update CI-09 and
   `README.md` configuration table together.
4. Verify CI-01…CI-03 and CI-12 against the live service at each release and
   attach the result to the post-deployment review.

## 3. Known gaps

- No external uptime prober; if the process is dead, SLI metrics measure nothing
  (`BackendDown` alert exists in `monitoring/prometheus-alerts.yml`).
- Alertmanager delivery is an inert local webhook; Slack template is committed
  but unproven (`monitoring/alertmanager.slack.example.yml`).
- Production rollback rehearsal and DB backup evidence remain open manual gates.
