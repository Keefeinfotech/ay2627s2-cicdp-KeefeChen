# Changelog

All notable changes to Auxilia are documented here.

## [Unreleased]

### Added
- API versioning: all application routes are now served under the canonical `/api/v1` prefix (legacy `/api` mount retained for backward compatibility).
- Productivity analytics endpoints: `GET /api/v1/analytics/weekly` (weekly created/completed counts, completion rate, on-time completions, overdue count, completion streak).
- AI-style task prioritisation: `GET /api/v1/analytics/priority-suggestions` and `POST /api/v1/analytics/priority-suggestions/apply`, scoring open tasks by deadline proximity and progress state.
- Unit tests for the analytics module.
- Redis cache-aside for the weekly analytics summary (60s TTL, fail-open).
- In-process background job queue (`shared/jobs/`) with analytics cache invalidation wired to task mutations.
- Microservices extraction implemented and integrated: `backend/prototype/notification-service/` (zero-dependency Node service, `Dockerfile`) runs as the `notification-service` compose service; the backend calls it via `services/notification.service.ts` (fail-open HTTP client, `NOTIFICATION_SERVICE_URL`) through the background job queue; reminder creation enqueues a notification. See `docs/microservices-prototype.md`.
- CDN-ready cache headers in `frontend/nginx.conf` and `docs/cdn.md`.
- Animated gradient background for a lively, dynamic UI.
- In-app announcement banner for deployment notices.
- SBOM/SLSA provenance, DAST (OWASP ZAP), and environment promotion workflows.
- Issue and PR templates, Lighthouse CI, rollback workflow.
- Prometheus alerting rules for error rate, latency, and uptime.

### Changed
- Constructors use initializing formals (perf cleanup).

## [1.0.0] - 2026-11-14

- Initial release: offline-first task manager, accounts, AI assistant, admin console.
