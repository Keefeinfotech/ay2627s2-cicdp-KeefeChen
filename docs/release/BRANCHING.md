# Branch Naming Conventions

This document is the repository's branch naming standard. It exists so every
branch makes its purpose obvious, so automation can rely on prefixes, and so
releases and rollbacks stay predictable.

## Prefixes

| Prefix | Usage | Example | Purpose |
|---|---|---|---|
| `feature/` | New functionality or UI components | `feature/participant-pagination` | New user-facing behaviour |
| `bugfix/` | Non-critical bug fixes | `bugfix/fix-null-pointer-edit` | Broken but not production-fatal behaviour |
| `hotfix/` | Emergency production fixes directly off `main` | `hotfix/db-connection-leak` | Urgent fixes that skip the normal release train |
| `refactor/` | Code maintenance without functional changes | `refactor/cleanup-jdbc-scriptlet` | Restructuring with no behaviour change |

Rules:

1. The prefix goes first, followed by a short kebab-case slug
   (`feature/<slug>`). Keep slugs short (`fix-null-pointer-edit`, not a full
   sentence).
2. `hotfix/` branches are cut from `main` and may merge ahead of the normal
   release train. Every other branch merges through the usual review and CI
   gates.
3. `feature/`, `bugfix/` and `refactor/` branches are cut from `main` (or the
   active integration branch) and merge back via pull request.
4. Do not reuse a branch for a second, unrelated task. One branch = one story.
5. Bot branches (`dependabot/*`, `renovate/*`) and `release/*` branches are
   allowed for their automation and release semantics respectively and are
   exempt from rule 1.

## Why this helps branching strategy

- **Traceability at a glance**: reviewers and CI know the scope before
  opening the PR; fixing a typo in a `bugfix/` branch signals no new behaviour.
- **Safer release trains**: `hotfix/` is the only path that bypasses the
  normal gates, so emergency fixes are visible and auditable in one grep.
- **Predictable CI**: the PR Conventions gate can enforce the prefix instead
  of relying on reviewer memory.
- **Clean rollbacks**: `refactor/` branches contain no functional change, so
  they are the safest candidates to revert first when bisecting a regression.

## Current branches under this convention

| Branch | Prefix | Reason |
|---|---|---|
| `feature/natural-language-task-assistant` | `feature/` | New AI assistant + onboarding UI (NP-19, NP-46) |
| `fix/frontend-assistant-compile-errors` | `bugfix/` (re-cut as `bugfix/...`) | Compile/type errors only; no new behaviour |

The local branch currently called `fix/frontend-assistant-compile-errors`
maps to the `bugfix/` prefix. PR #13 should use
`bugfix/frontend-assistant-compile-errors` (rename or close the redundant
duplicate; PR #12 already complies with `feature/`).

## Enforcement

The `Source Control - PR Conventions` job in `.github/workflows/ci.yml`
rejects pull requests whose head branch does not match one of the allowed
prefixes. Rename the branch (or re-cut it) and the gate passes.
