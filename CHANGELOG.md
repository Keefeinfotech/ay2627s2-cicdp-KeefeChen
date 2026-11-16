# Changelog

All notable changes to Auxilia are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Entries focus on meaningful, user-facing or system-level changes; see
`docs/change-management/change-log.md` for the fuller traceable record.

## [Unreleased]

### Added
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
- Production deployment health gate: the Render health check polled a non-existent hostname (`x-render-routing: no-server`); the `production` environment variable `RENDER_API_BASE_URL` was corrected to the live service on 2026-11-16.

### Security
- _No entries yet._

### Deprecated
- _None._

### Removed
- _None._ (MIT license removal is legal/housekeeping, not user-facing; see `docs/change-management/change-log.md`.)

## [1.0.0] - 2026-11-14

### Added
- Initial release: offline-first task manager, accounts, AI assistant, admin console.

[Unreleased]: https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/Keefeinfotech/ay2627s2-cicdp-KeefeChen/compare/v0.1.0...v1.0.0
