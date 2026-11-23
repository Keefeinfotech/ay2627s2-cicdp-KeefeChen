# Code Review Policy — Auxilia

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** Project owner
**Purpose:** make code review systematic and evidence-based rather than relying
on "CI is green". Complements the PR template and CODEOWNERS.

## 1. Review tiers

| Tier | Triggers | Required review | Merge condition |
|---|---|---|---|
| **Tier 1 — critical** | `backend/src/modules/auth/**`, `middleware/**`, `shared/utils/tokens.ts`, migrations/schemas, `.github/workflows/**`, `render.yaml`, `docker-compose.yml`, secrets handling | One independent reviewer **or** a completed formal self-inspection checklist (below), plus full CI | Required gate green + checklist in PR + CAB/CCB ID where applicable |
| **Tier 2 — normal** | Feature/bugfix changes in `frontend/lib/**`, `backend/src/modules/**` | Author self-review against PR template; reviewer welcome | Required gate green |
| **Tier 3 — routine** | Docs, dependency bumps, test-only changes | Author self-review | Required gate green |

This is a solo project: where an independent reviewer is not available, the
formal self-inspection checklist is the accepted substitute and must be pasted
into the PR description. This is an explicit, auditable decision — not a silent
absence of review.

## 2. Formal self-inspection checklist (Tier 1)

Paste into the PR and tick every item:

```markdown
- [ ] Requirement / issue linked; acceptance criteria restated
- [ ] Correctness: all branches and error paths handled
- [ ] Security: new inputs validated; no secrets or tokens logged; authz checked server-side
- [ ] Data: schema change backward compatible or migration supplied; rollback considered
- [ ] API contract: Zod/route/OpenAPI/Pact updated if the shape changed
- [ ] Tests: success + failure paths covered; regression test added for the defect
- [ ] Coverage ratchet not lowered; new files not silently excluded
- [ ] Rollback plan stated (LAST_GOOD_SHA / prior tag)
- [ ] Documentation updated (RTM, change log, README/docs, release evidence)
- [ ] CI green: backend + frontend + E2E + security gates + Final Quality Gate
```

## 3. Automated quality tools (mandatory gates)

| Concern | Tool | Enforced in |
|---|---|---|
| Types / analysis | `tsc --noEmit`, ESLint, `flutter analyze`, `dart format` | `ci.yml`, `Jenkinsfile` |
| Tests / coverage | Vitest, flutter_test, Pact, 58/48/59/58 + 62% ratchets | `ci.yml` |
| Security | Trivy (fs + image), Gitleaks, CodeQL, dependency review, npm audit | `ci.yml` |
| Quality / runtime | SonarCloud, Lighthouse, ZAP baseline, Stryker (advisory) | `ci.yml`, `dast.yml`, `mutation.yml` |
| E2E / a11y | Playwright × 4 projects, axe-core | `ci.yml` |

## 4. CODEOWNERS

`.github/CODEOWNERS` maps paths to teams. Verify that every listed owner
(`@Keefeinfotech/auxilia-maintainers`, `backend-team`, `frontend-team`,
`devops-team`, `docs-team`, `security-team`) resolves on this account; if the
repository is personal rather than organisation-owned, replace team handles
with individual users so review requests are actually delivered.

## 5. Evidence

Record review evidence in the PR "Testing performed" and completion checklist.
At each release, count Tier-1 PRs with a completed checklist and add the figure
to the post-deployment review. PRs that change auth, data or deployment must
reference a `CCB-*`/`CAB-*` decision ID from
[../change-management/GOVERNANCE.md](../change-management/GOVERNANCE.md).
