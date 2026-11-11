## Summary

Describe the user-visible change and the problem it solves.

## Sprint story

- Jira: `NP-__`
- Story outcome:

## Changes

- [ ] Frontend
- [ ] Backend
- [ ] CI / documentation

## CI/CD Checklist

- [ ] All CI gates green (Dependabot review, PR conventions, security scans, backend, frontend, SonarCloud)
- [ ] Draft PR: CI results are non-blocking until marked "ready for review"
- [ ] No new secrets, `.env` files, or local build output committed
- [ ] PR title follows Conventional Commits (e.g. `feat(tasks): add deadline reminders`)
- [ ] Branch rebased onto latest `main` before merge

## Verification

Paste the commands and results that prove this change works.

```text
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart 60
npm run format:check
npm run lint
npm run test:coverage
npm run build
```

- [ ] Tests added or updated for new behaviour
- [ ] Accessibility checked (semantics, 200% text scale) when UI changed
- [ ] PR title follows Conventional Commits

## Risk and rollback

- Risk:
- Rollback: revert this pull request.

## Screenshots

Attach light and dark screenshots for UI changes, or write "not applicable".
