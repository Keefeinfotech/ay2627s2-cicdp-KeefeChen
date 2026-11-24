# Changelog

All notable changes to Auxilia are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries focus on meaningful, user-facing or system-level changes; see
`docs/change-management/change-log.md` for the fuller traceable record.

## [Unreleased]

### Added
- Customisable calendar appearance: five skins (System, Midnight, Aurora, Sandstone, Orchid), separable day squares with three corner styles, and private per-day marks (focus, done, important, personal) persisted per workspace.
- Enterprise DevSecOps hardening: pinned third-party Actions enforced in CI (`actions-security` job + `check-action-pins.mjs`), SBOM artifacts generated and uploaded from CI, `SECURITY_GOVERNANCE.md` with a severity escalation matrix and remediation tracking, and `REPOSITORY_SECURITY_RULES.md` documenting GitHub-side settings.
- API versioning: all application routes are now served under the canonical `/api/v1` prefix (legacy `/api` mount retained for backward compatibility).
- Productivity analytics endpoints: `GET /api/v1/analytics/weekly` (weekly created/completed counts, completion rate, on-time completions, overdue count, completion streak).
- AI-style task prioritisation: `GET /api/v1/analytics/priority-suggestions` and `POST /api/v1/analytics/priority-suggestions/apply`, scoring open tasks by deadline proximity and progress state.
- Unit tests for the analytics module.
- Redis cache-aside for the weekly analytics summary (60s TTL, fail-open).
- In-process background job queue (`shared/jobs/`) with analytics cache invalidation wired to task mutations.
- Microservices extraction implemented and integrated: `backend/prototype/notification-service/` (zero-dependency Node service, `Dockerfile`) runs as the `notification-service` compose service; the backend calls it via `services/notification.service.ts` (fail-open HTTP client, `NOTIFICATION_SERVICE_URL`) through the background job queue; reminder creation enqueues a notification. See `docs/microservices-prototype.md`.
- CDN-ready cache headers in `frontend/nginx.conf` and `docs/cdn.md`.
- API expansion: `POST /auth/change-password`, `POST /auth/logout-all`, `PATCH /users/me/email`, dedicated `PATCH /tasks/:id/status|priority|due-date`, `POST /tasks/:id/complete|reopen`, `POST /tasks/bulk`, `PATCH /tasks/bulk/status`, `DELETE /tasks/bulk`, reminder recurrence/task linkage/`PATCH`/`upcoming` + IDOR fix, `GET /health/ready|live`, full `/analytics/*` suite, `/notifications` (in-app + devices), `/preferences`, `/sync/push|pull|batch|status|resolve-conflict` (idempotent ops), `/assistant/interpret|clarify|preview|confirm|cancel|suggestions` (confirmation-gated).
- Swagger documentation for all new endpoints; `docs/api-audit.md` gap analysis.
- Frontend: reminder repository rewritten to work against the authenticated API with the current envelope.
- UX polish: unsaved-changes guard in the task editor (confirm-discard dialog), animated show/hide for the sync status strip (no more layout jumps), cross-fade route transitions, sync-queue discard and admin deactivation confirmed before applying, home/admin/reminders screens load with skeletons instead of blocking spinners, live field validation on auth forms (login/forgot/reset), gradient background honours OS reduce-motion and repaints in isolation.
- Change management process and change log (`docs/change-management/`), change request template, and updated feature/bug templates with impact assessment.
- Optional Redis-backed rate-limit counters shared across replicas. (#72)
- Animated gradient background for a lively, dynamic UI. (#66)
- In-app announcement banner for deployment notices. (#67)
- SBOM/SLSA provenance, DAST (OWASP ZAP), and environment promotion workflows.
- Issue and PR templates, Lighthouse CI, rollback workflow. (#64, #67)
- Prometheus alerting rules for error rate, latency, and uptime.

### Changed
- Constructors use initializing formals (perf cleanup).
- Pull request template now requires linked issue, impact assessment, security considerations, regression risks and testing evidence.

### Fixed
- Release workflow SBOM generation: scan the packaged web tarball as a file (`file:`) instead of a directory path (`path:`), fixing the `v1.0.0` release publish failure. (#155)
- Production deployment health gate: the Render health check polled a non-existent hostname (`x-render-routing: no-server`); the `production` environment variable `RENDER_API_BASE_URL` was corrected to the live service on 2026-11-16.

### Security
- Removed the development `JWT_SECRET` fallback from `docker-compose.yml`. Local, CI and Jenkins stacks must now supply an explicit secret; production was already correct because Render injects the real value. (#125)

### Deprecated
- _None._

### Removed
- _None._ (MIT license removal is legal/housekeeping, not user-facing; see `docs/change-management/change-log.md`.)

## [1.0.0] - 2026-11-14

### Added
- Initial release: offline-first task manager, accounts, AI assistant, admin console.

[Unreleased]: https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/compare/v0.1.0...v1.0.0
