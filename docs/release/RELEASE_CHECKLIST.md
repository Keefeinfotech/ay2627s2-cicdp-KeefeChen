# Release Checklist

Use this checklist for every tagged release (or approved release candidate). Work through it in order and keep the completed checklist with the release notes. The full testing strategy and test-suite inventory live in [docs/testing/TESTING_STRATEGY.md](../testing/TESTING_STRATEGY.md); the manual test plan is [docs/testing/MANUAL_TEST_PLAN.md](../testing/MANUAL_TEST_PLAN.md).

> **Integrated model:** Production deployment is performed **inside the Release Workflow** (staging → approval gate → production CD → post-deploy verification → rollback). See [RELEASE_WORKFLOW_INTEGRATED.md](../deployment/RELEASE_WORKFLOW_INTEGRATED.md). This checklist covers preparation, verification, security/privacy, and release governance; pipeline automation steps are documented there and in `docs/deployment/CICD_CONFIGURATION.md`.

## 1. Prepare

- [ ] Create a `release/x.y.z` branch from `develop` (or `main` if there is no
      develop branch). Name all branches per `docs/release/BRANCHING.md`
      (`feature/`, `bugfix/`, `hotfix/`, `refactor/`, or `release/`).
- [ ] Confirm the working tree is clean and CI on the source branch is green.
- [ ] Update the version in `frontend/pubspec.yaml`
      (`version: x.y.z+build`) and `backend/package.json`.
- [ ] Review merged pull requests for anything that changes data storage,
      authentication, or the public API.
- [ ] Confirm documentation is current: `README.md`,
      `docs/planning/PROJECT_PLAN.md`, `docs/compliance/NFR_RELEASE_GATES.md`,
      `docs/compliance/PRIVACY.md`, `docs/release/DEPENDENCIES.md`.

## 2. Verify locally

```bash
cd backend
npm ci
npm run typecheck
npm run test:coverage
npm run test:functional
npm run test:regression
npm run test:ai
npm run build

cd ../frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 62
flutter build web --release
```

- [ ] All commands above pass.
- [ ] Backend coverage meets the thresholds in `backend/vitest.config.mts`.
- [ ] Frontend line coverage meets the 62% gate.
- [ ] No new `flutter analyze` warnings or infos.

## 3. Review security and privacy

- [ ] No secrets, tokens, `.env` files, or keystores are staged
      (`git diff --cached`).
- [ ] `JWT_SECRET` for the target environment is at least 16 characters and is
      stored in the platform secret manager, not in the repository.
- [ ] `CORS_ORIGIN` lists only the deployed web origins.
- [ ] `NODE_ENV=production` so Swagger UI is not served.
- [ ] Trivy results from the latest CI run reviewed; any accepted risk is
      recorded in the release notes.
- [ ] Dependency Review results for merged pull requests contain no high or
      critical findings, or the exceptions are recorded in the release notes.
- [ ] Privacy impact considered: no new personal data collected or transmitted
      without updating `docs/compliance/PRIVACY.md`.

## 4. Deploy (integrated Release Workflow)

> If the Release Workflow automates staging/production deployment, treat the items below as **controls to verify** (and as manual runbook steps for break-glass/emergency deploys).

- [ ] Back up the production database (before production promotion, as applicable).
- [ ] Apply MongoDB schema validators (`$jsonSchema` on every collection):
      `npm run validate:collections` with the target `MONGODB_URI` set. Verify validators are active (e.g. `db.getCollectionInfos()` shows validators) and rejection behavior is understood.
- [ ] **Staging:** confirm automated deploy completed and `GET /api/health` returns `200` on staging.
- [ ] **Staging:** confirm a signup and login succeed against staging API over HTTPS (or agreed test flow).
- [ ] **Production (after approval/CD):** confirm `GET /api/health` returns `200` on production.
- [ ] **Production:** confirm a signup/login smoke (or equivalent critical path) succeeds over HTTPS.
- [ ] Frontend is built with the correct `API_BASE_URL` for the promoted environment; confirm the app loads and core offline task flow works (create/complete) as appropriate.

## 5. Smoke test

Run the non-mutating API smoke test first:

```bash
node scripts/smoke-test.mjs https://<api-host>
```

- [ ] Smoke test passes (`/api/health` returns 200, unauthenticated AI chat
      returns 401, unknown API routes return 404).
- [ ] Create, edit, complete, delete, and clear tasks.
- [ ] Reload the app and confirm tasks persist.
- [ ] Sign up, sign out, and sign back in; confirm the session is restored.
- [ ] Confirm anonymous users cannot call `POST /api/ai/chat`
      (expect `401`).
- [ ] Confirm the AI assistant returns the mock response when
      `AI_PROVIDER=mock`.

## 6. Roll back plan

- [ ] Previous known-good commit/SHA (`LAST_GOOD_SHA` or documented equivalent) is identified and deployable.
- [ ] Previous web artifacts/builds are retained as needed for traceability.
- [ ] Database backup can be restored if data-impacting changes occurred.
- [ ] In the integrated flow, rollback may be **automatic** on production deploy/smoke failure (to `LAST_GOOD_SHA`) and/or **manual** via `rollback.yml`; always verify with health + `scripts/smoke-test.mjs` and record an incident note.

## 7. After release

- [ ] Tag `v*.*.*` and push; the release workflow verifies versions, reruns CI,
      packages `frontend/build/web`, attests provenance, and publishes the
      GitHub release with notes.
- [ ] Or, for a manual release, publish the same artifact and attach this
      checklist to the release notes.
- [ ] Merge `release/x.y.z` back into `develop` and `main`.
- [ ] Watch error logs and CI for 24 hours.
- [ ] Close follow-up issues created for deferred work.
