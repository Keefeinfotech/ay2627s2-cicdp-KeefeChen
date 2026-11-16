# Contributing to Auxilia

Thank you for contributing to Auxilia! This document outlines the process for
making changes to the repository.

## Getting Started

1. Fork the repository and clone your fork locally.
2. Create a new branch from `main` for your work:
   ```bash
   git checkout -b feat/your-feature-name
   ```
3. Make your changes and commit using [Conventional Commits](https://www.conventionalcommits.org/).
4. Push your branch and open a pull request against `main`.

## Branch Naming

Use one of the prefixes enforced by the `Source Control - PR Conventions` CI
job (see [docs/release/BRANCHING.md](docs/release/BRANCHING.md)):

| Prefix | Use case |
|--------|----------|
| `feature/` | New feature |
| `bugfix/` | Bug fix |
| `hotfix/` | Urgent production fix |
| `refactor/` | Code refactor without behavior change |
| `release/` | Release preparation |

Docs, tests and chore changes ride on the closest matching prefix
(e.g. `feature/add-tests`, `bugfix/fix-typo`); bot branches (`dependabot/`,
`renovate/`) are exempt.

## Commit Message Format

All commit titles and PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>
```

Examples:

- `feat(tasks): add deadline reminders`
- `fix(auth): validate password strength on signup`
- `docs(readme): update contributing guidelines`
- `chore(ci): pin CodeQL action version`

The CI will reject PR titles that do not match this pattern.

## Pull Request Requirements

This repository uses the traceable workflow: **issue → branch → pull request → CI → merge → changelog**. Every pull request must link its issue (`Closes #<issue-number>`), and changes to changelog/change-log are expected for anything user-facing or system-level.

Before opening a PR, ensure:

- [ ] Your branch is up to date with `main` (rebase if needed).
- [ ] All existing tests pass locally.
- [ ] You have added or updated tests for any new behavior.
- [ ] Frontend: `flutter analyze`, `flutter test --coverage`, and coverage >= 60%.
- [ ] Backend: `npm run format:check`, `npm run lint`, `npm run test:coverage`, `npm run build`.
- [ ] No secrets, `.env` files, or build output are committed.
- [ ] UI changes include light and dark mode screenshots (or "not applicable").
- [ ] Accessibility checked (semantics, 200% text scale) for UI changes.
- [ ] PR title follows Conventional Commits.

The following CI checks run on every PR:

1. **Dependency Review** — fails on high-severity vulnerable dependencies.
2. **PR Conventions** — validates Conventional Commits title format.
3. **Security Scan** — Trivy filesystem + container image scan.
4. **Secret Scan** — Gitleaks scan for leaked credentials.
5. **CodeQL** — Static analysis for JavaScript/TypeScript.
6. **Backend** — format check, audit, lint, tests with coverage, build.
7. **Frontend** — `pub get --enforce-lockfile`, format, analyze, tests, coverage, web build.
8. **SonarCloud** — Quality gate check.
9. **Final Quality Gate** — Aggregates all results.

A PR can only be merged when all required checks pass.

## Change Management

All non-trivial changes follow the process in
[docs/change-management/change-management-process.md](docs/change-management/change-management-process.md):

1. File a GitHub Issue — `change_request.md` for broad-impact changes,
   `feature_request.md` / `bug_report.md` otherwise.
2. The maintainer approves, rejects or defers the change in the issue.
3. Implement on a `feature/`/`bugfix/`/`hotfix/`/`refactor/` branch and open a
   pull request that closes the issue.
4. CI gates must pass; docs-only changes skip CI via `paths-ignore`.
5. Update `CHANGELOG.md` and `docs/change-management/change-log.md`, then the
   issue closes on merge.

## Review Process

1. A maintainer will review your PR and may request changes.
2. Address review feedback by pushing new commits to your branch.
3. Once approved and all CI checks pass, a maintainer will merge your PR.
4. Do not force-push to a shared branch unless you own it.

## Code of Conduct

Be respectful and inclusive. Report unacceptable behavior to the project
maintainers.
