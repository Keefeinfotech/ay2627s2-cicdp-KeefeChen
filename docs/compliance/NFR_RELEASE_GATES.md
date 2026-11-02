# NFR Release Gates

These gates translate the non-functional requirements into checks that must pass
before a change reaches `main` or is released. Automated gates run in
`.github/workflows/ci.yml`; manual gates are part of the
[release checklist](RELEASE_CHECKLIST.md).

## Automated gates

| ID | Area | Requirement | How it is verified | Blocking |
|----|------|-------------|--------------------|----------|
| G1 | Type safety | No type errors in either codebase | `cd backend && npm run typecheck`; `cd frontend && flutter analyze` | Yes |
| G2 | Formatting | Dart sources are canonically formatted | `dart format --output=none --set-exit-if-changed lib test tool` | Yes |
| G3 | Backend tests | All Vitest suites pass | `npm run test:coverage` | Yes |
| G4 | Backend coverage | Statements >= 80%, branches >= 60%, functions >= 80%, lines >= 80% (excluding `src/server.ts`, `src/swagger.ts`, `src/types/**`) | `vitest` coverage thresholds in `backend/vitest.config.mts` | Yes |
| G5 | Frontend tests | All Flutter tests pass, including widget tests for the dashboard, task card, task editor, undo, session restore, and 200% text scaling | `flutter test --coverage` | Yes |
| G5b | Frontend coverage | Line coverage >= 60% | `dart run tool/check_coverage.dart 60` after `flutter test --coverage` | Yes |
| G6 | Build | Backend compiles; web release build succeeds | `npm run build`; `flutter build web --release` | Yes |
| G7 | Dependency scan | Known CRITICAL/HIGH vulnerabilities are surfaced | Trivy filesystem scan, SARIF uploaded to code scanning | No (report-only, reviewed each release) |
| G8 | Secrets | No committed secrets; the API refuses to start without a strong JWT secret | `.gitignore` covers `.env`; `assertRuntimeEnv()` exits when `JWT_SECRET` is missing or shorter than 16 characters | Yes |
| G9 | Auth and input safety | Protected endpoints reject anonymous callers; malformed input is rejected with structured errors | Integration tests; Zod schemas; 10 kb body limit; rate limits (auth 10 per 15 min, AI `AI_RATE_LIMIT_PER_USER` per hour, default 20) | Yes |
| G10 | Privacy | Tasks stay on the device; no analytics or telemetry | Code review; [PRIVACY.md](PRIVACY.md) | Yes |
| G11 | Accessibility | Status is not conveyed by colour alone; controls have labels/tooltips; layout survives 200% text scaling | Widget tests (`find.bySemanticsLabel`, 2x `TextScaler`, narrow viewport); review checklist | Yes |
| G12 | Reliability | Failed writes leave previous data intact; failed reads show a retry path; shutdown is graceful | Store/repository unit tests; integration review | Yes |
| G13 | Performance | Task lists are paginated (20 per page default) and task operations require no network | Unit/widget tests; architecture review | Yes |
| G14 | Compatibility | Flutter 3.47.8 (Dart >= 3.13), Node.js >= 22.12, web build | CI toolchain pins; `pubspec.lock`; `engines` in `package.json` | Yes |

## Coverage policy

Coverage is a floor, not a target. New behaviour needs tests that exercise both
the success path and the failure path (storage errors, validation errors,
unauthorised requests). Coverage exclusions are limited to process wiring
(`server.ts`), the generated OpenAPI document (`swagger.ts`), and type-only
declarations.

## Manual gates (each release)

- Screen-reader pass on one mobile platform (TalkBack or VoiceOver).
- 200% text scale and narrow-screen pass on a physical device or emulator.
- HTTPS enforced for the deployed API; CORS origin matches the deployed web app.
- Database backup taken before migrations or destructive changes.
- Trivy findings triaged; accepted risks recorded in the release notes.

## Exceptions

Any gate that cannot be met must be recorded in the pull request with the
reason, the residual risk, and a follow-up issue. Security and privacy gates
(G8, G9, G10) cannot be waived.
