# Release Checklist

Use this checklist for every tagged release. Work through it in order and keep
the completed checklist with the release notes.

## 1. Prepare

- [ ] Create a `release/x.y.z` branch from `develop` (or `main` if there is no
      develop branch).
- [ ] Confirm the working tree is clean and CI on the source branch is green.
- [ ] Update the version in `frontend/pubspec.yaml`
      (`version: x.y.z+build`) and `backend/package.json`.
- [ ] Review merged pull requests for anything that changes data storage,
      authentication, or the public API.
- [ ] Confirm documentation is current: `README.md`,
      `docs/PROJECT_PLAN.md`, `docs/NFR_RELEASE_GATES.md`, `docs/PRIVACY.md`,
      `docs/DEPENDENCIES.md`.

## 2. Verify locally

```bash
cd backend
npm ci
npm run typecheck
npm run test:coverage
npm run build

cd ../frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 60
flutter build web --release
```

- [ ] All commands above pass.
- [ ] Backend coverage meets the thresholds in `backend/vitest.config.mts`.
- [ ] Frontend line coverage meets the 60% gate.
- [ ] No new `flutter analyze` warnings or infos.

## 3. Review security and privacy

- [ ] No secrets, tokens, `.env` files, or keystores are staged
      (`git diff --cached`).
- [ ] `JWT_SECRET` for the target environment is at least 16 characters and is
      stored in the platform secret manager, not in the repository.
- [ ] `CORS_ORIGIN` lists only the deployed web origins.
- [ ] `NODE_ENV=production` so Swagger UI is not served.
- [ ] Trivy results from the latest CI run reviewed; any accepted risk is
      recorded.
- [ ] Privacy impact considered: no new personal data collected or transmitted
      without updating `docs/PRIVACY.md`.

## 4. Deploy

- [ ] Back up the production database.
- [ ] Deploy the backend, then confirm `GET /api/health` returns `200`.
- [ ] Confirm a signup and a login succeed against the deployed API over HTTPS.
- [ ] Build and deploy the web frontend with
      `--dart-define=API_BASE_URL=https://<api-host>`.
- [ ] Confirm the frontend loads and a task can be created and completed
      offline.

## 5. Smoke test

- [ ] Create, edit, complete, delete, and clear tasks.
- [ ] Reload the app and confirm tasks persist.
- [ ] Sign up, sign out, and sign back in; confirm the session is restored.
- [ ] Confirm anonymous users cannot call `POST /api/ai/chat`
      (expect `401`).
- [ ] Confirm the AI assistant returns the mock response when
      `AI_PROVIDER=mock`.

## 6. Roll back plan

- [ ] Previous backend image/commit is known and deployable.
- [ ] Previous web build is retained.
- [ ] Database backup can be restored.
- [ ] If a release fails smoke testing: revert the deployment, restore the
      backup if data changed, and open an incident note.

## 7. After release

- [ ] Tag the release and publish release notes (changes, known issues,
      accepted risks).
- [ ] Merge `release/x.y.z` back into `develop` and `main`.
- [ ] Watch error logs and CI for 24 hours.
- [ ] Close follow-up issues created for deferred work.
