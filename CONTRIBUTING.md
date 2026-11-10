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

Use one of the following prefixes:

| Prefix | Use case |
|--------|----------|
| `feat/` | New feature |
| `fix/` | Bug fix |
| `docs/` | Documentation only |
| `refactor/` | Code refactor without behavior change |
| `perf/` | Performance improvement |
| `test/` | Adding or fixing tests |
| `chore/` | Build, CI, or maintenance |
| `hotfix/` | Urgent production fix |

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

## Review Process

1. A maintainer will review your PR and may request changes.
2. Address review feedback by pushing new commits to your branch.
3. Once approved and all CI checks pass, a maintainer will merge your PR.
4. Do not force-push to a shared branch unless you own it.

## Code of Conduct

Be respectful and inclusive. Report unacceptable behavior to the project
maintainers.
