# Change Log

Traceable record of significant changes to Auxilia. Minor commits are not
listed here; see `CHANGELOG.md` for the user-facing history and `git log` for
commit-level detail. Format:

| Date | Reference | Description | Category | Status | PR / Release |
|---|---|---|---|---|---|

Status values: `Released` · `Merged` · `Completed (configuration)` · `Planned`.

| Date | Reference | Description | Category | Status | PR / Release |
|---|---|---|---|---|---|
| 2026-10-27 | v0.1.0 | Initial pre-release: offline-first task manager MVP (tasks, dashboard, local persistence) | Release | Released (pre-release) | [v0.1.0](https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/releases/tag/v0.1.0) |
| 2026-10-29 | Ruleset `Protect main branch` | `main` protected: pull requests required, deletion and force-push blocked | Configuration | Completed (configuration) | GitHub ruleset |
| 2026-11-14 | v1.0.0 | Initial stable release: accounts, AI assistant, sync, groups, admin console | Release | Released | [v1.0.0](https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/releases/tag/v1.0.0) |
| 2026-11-16 | PR #64 | Issue/PR templates, Lighthouse CI, rollback workflow, demo docs | Process / CI | Merged | PR #64 |
| 2026-11-16 | PR #67 | Deployment plan, rollback runbook, alerting rules, announcement banner, changelog | Process / DevOps | Merged | PR #67 |
| 2026-11-16 | PR #66 | Animated gradient background for the web/app UI | Feature (frontend) | Merged | PR #66 |
| 2026-11-16 | PR #72 | Share rate-limit counters across replicas via optional Redis | Feature (backend) | Merged | PR #72 |
| 2026-11-16 | PR #73 | Remove MIT license per security advice | Housekeeping / legal | Merged | PR #73 |
| 2026-11-16 | Render/GitHub variable | Production deploy health gate was failing: `RENDER_API_BASE_URL` pointed at a non-existent Render hostname (`x-render-routing: no-server`). Corrected the `production` environment variable to the live service URL; deploy workflow green (run 43785243575) | Configuration / Fix | Completed (configuration) | deploy-production.yml |
| 2026-11-23 | Issue #125 | Removed the development `JWT_SECRET` fallback from `docker-compose.yml`; CI e2e/performance and Jenkins local deploy now supply an explicit test-only secret | Configuration / Security | Merged | issue #125 |
