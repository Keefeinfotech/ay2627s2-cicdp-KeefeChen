# Release Evidence — Auxilia v1.0.0

## Release identifiers
- Tag: `v1.0.0`
- Backend version (`backend/package.json`): 1.0.0
- Frontend version (`frontend/pubspec.yaml`): 1.0.0+1
- Tag SHA: `<fill after tagging>`
- Release date: `<fill>`

## CI / pipeline evidence
- CI run (pull_request): `<URL>`
- CI run (push/tag): `<URL>`
- SonarCloud quality gate: OK
- Trivy (fs + image): no CRITICAL/HIGH
- CodeQL: no new alerts
- Gitleaks: passed
- Provenance attestation: `<URL>`
- GitHub release page: `<URL>`

## Build artifacts
- Web bundle: `auxilia-web-v1.0.0.tar.gz`
- SBOM: `auxilia-web-v1.0.0.sbom.spdx.json`

## Runtime verification
- Render deployment URL: `<URL>`
- `GET /api/health` response: `<paste>`
- Smoke test (`scripts/smoke-test.mjs`) output: `<paste>`
- HTTPS / CORS headers (`curl -I`): `<paste>`

## NFR manual gates
| Gate | Status | Date | Evidence |
|---|---|---|---|
| 200% text scale on device | ☐ | | screenshot |
| Screen reader / axe DevTools | ☐ | | screenshot |
| DB backup (mongodump) | ☐ | | artifact |
| HTTPS + CORS | ☐ | | curl output |

## Rollback rehearsal
- Previous build: `<id>`
- Re-deployed: `<timestamp>`
- Total recovery time: `<minutes>`
- Notes: `<fill>`

## Known limitations
| Item | Notes |
|---|---|
| Trivy | CRITICAL/HIGH blocking enabled |
| Coverage ratchet | 62% gate |
| Smoke test write canary | gated behind `SMOKE_WRITE=true` on staging only |