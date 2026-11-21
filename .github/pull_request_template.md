<!--
Pull requests are the change-control gate for Auxilia. Link this PR to the
issued GitHub Issue so request -> implementation -> verification stays
traceable. Process: docs/change-management/change-management-process.md
-->

## Summary
Describe the user-visible change and the problem it solves.

## Reason
Why is this change needed, and what request or requirement does it fulfil?

## Related issue
Closes #<issue-number>

## Sprint story (optional)
- Jira: `NP-__`
- Story outcome:

## Implementation details
What changed, and how? Note any trade-offs, new dependencies or migration steps.

## Impact assessment
- Requirements:
- Architecture (frontend / backend / shared):
- Security (auth, authorisation, JWT, secrets, middleware, CAPTCHA):
- Database (MongoDB/Mongoose, Drift/SQLite, sync, backfill):
- API contract (Zod, routes, OpenAPI, Pact):
- Testing (unit / integration / regression / contract / e2e):
- Deployment / CI-CD (Docker, GitHub Actions, Render, smoke checks):

## Testing performed
Paste the commands and results that prove the change works.

```text

```

## Security considerations
Any new input paths, permissions, data exposure, or dependency changes?

## Potential regression risks
What could break, and how was it checked? Note rollback steps if relevant.

## Documentation updates
- [ ] `CHANGELOG.md` (Unreleased) — user-facing or system-level changes
- [ ] `docs/change-management/change-log.md` — significant changes
- [ ] README / docs updated (or not applicable)

## Completion checklist
- [ ] Branch follows naming convention (`feature/`, `bugfix/`, `hotfix/`, `refactor/`)
- [ ] PR title follows Conventional Commits (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`)
- [ ] Related issue linked (`Closes #<issue-number>`)
- [ ] Tests added/updated and passing (`flutter test`, `npm run test:coverage`)
- [ ] `flutter analyze` / backend lint and typecheck pass
- [ ] CI green — including SonarCloud quality gate and Final Quality Gate
- [ ] Docs updated (or marked not applicable)
