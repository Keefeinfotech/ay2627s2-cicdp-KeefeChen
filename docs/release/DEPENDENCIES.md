# Dependencies

This document lists the runtime and development dependencies, why they are
used, and how they are kept healthy. Lockfiles (`backend/package-lock.json`,
`frontend/pubspec.lock`) are committed and CI installs from them.

## Backend (Node.js >= 22.12)

| Package | Purpose |
|---------|---------|
| `express` | HTTP API |
| `mongoose` | MongoDB models and connection |
| `bcryptjs` | Password hashing (pure JS, no native build step) |
| `jsonwebtoken` | Session tokens (HMAC-signed) |
| `zod` | Request validation |
| `helmet` | Security headers |
| `cors` | Origin allowlist |
| `express-rate-limit` | Throttling for auth and AI routes |
| `dotenv` | Local environment loading |
| `swagger-ui-express`, `openapi-types` | Interactive API docs in non-production |

Development tooling: `typescript`, `tsx`, `vitest`, `@vitest/coverage-v8`,
`supertest`, `@types/*`.

## Frontend (Flutter 3.47.8, Dart >= 3.13)

| Package | Purpose |
|---------|---------|
| `flutter` | UI framework |
| `http` | API calls to the backend |
| `shared_preferences` | Local, offline-first task storage |
| `flutter_secure_storage` | Session token storage in platform secure storage |
| `cupertino_icons` | iOS-style icon assets |

Development tooling: `flutter_test`, `flutter_lints`.

## Update policy

- Dependencies are updated deliberately, not automatically; there is no bot
  configuration in the repository at present.
- Run `npm outdated` / `flutter pub outdated` before a release and review
  available updates.
- After any update, rerun the full gate set:
  `npm ci && npm run test:coverage && npm run build` and
  `flutter pub get && flutter analyze && flutter test`.
- Major-version upgrades require a dedicated pull request with release notes.
- Do not add a dependency when the standard library or an existing package
  covers the need.

## Vulnerability scanning

- CI runs Trivy against the filesystem and uploads CRITICAL/HIGH findings as
  SARIF to GitHub code scanning. The upload is report-only and does not block a
  merge; findings are triaged for each release.
- `npm audit` reports zero known vulnerabilities for the current lockfile.
- Review `docs/NFR_RELEASE_GATES.md` for the full gate list.

## Known constraints

- The web build targets JavaScript. Flutter's optional WebAssembly dry run is
  not part of CI; secure storage on the web relies on the browser's
  WebCrypto-backed storage and is only as strong as the deployed origin (HTTPS)
  and the user's device.
- `flutter_secure_storage` and `shared_preferences` are platform plugins; widget
  tests use in-memory fakes so no platform channel is required.
