---
name: Change request
about: Propose a change to requirements, features, source code, schema, API contracts or configuration
title: "change: "
labels: change-request
---

<!--
Use this template for any non-trivial change that affects requirements, application
features, source code, database schemas, API contracts, or system configuration.
Trivial defects can use the bug report template; pure ideas can use the feature
request template. The process this template feeds into is documented in
docs/change-management/change-management-process.md.
-->

## Change title

## Classification
- Change type: **Standard** (pre-approved, low risk) · **Normal** (CCB approval) · **Emergency** (CAB retro-approval within 1 working day)
- Requested by:
- Target release:
- CCB / CAB decision ID (if applicable):
- Rollback plan:
- Post-change verification plan:

## Description of the change

## Reason and justification
Why is this change needed? What happens if it is rejected or deferred?

## Proposed implementation
How should the change be built, at a high level? Which modules, services or layers are involved?

## Impact assessment
Rate each area: none / low / medium / high, and add notes.

| Area | Impact | Notes |
|---|---|---|
| Requirements | | |
| Architecture | | (Flutter/Riverpod/GoRouter/Drift · Express controller-service-repository · shared contracts) |
| Security | | (auth, authorisation, JWT, security middleware, secrets, CAPTCHA) |
| Database | | (MongoDB Atlas / Mongoose schema or indexes, migration or backfill, Drift/SQLite local schema) |
| API contract | | (Zod schemas, routes, OpenAPI, Pact contract tests) |
| Testing | | (unit, integration, regression, contract, e2e, coverage gates) |
| Deployment / CI-CD | | (Docker, GitHub Actions, SonarCloud, Trivy, Render, smoke checks) |
| Timeline | | (estimate, dependencies, deadline) |

## Priority
Select one: **Critical** (production down / data at risk) · **High** (release-blocking) · **Medium** (planned work) · **Low** (nice to have)

Priority:

## Potential risks and mitigation

## Acceptance criteria
- [ ]
- [ ]

## Related issues or requirements
<!-- Link related issues, user stories (NP-xx), requirements, or docs. -->

## Approval decision (maintainer completes)
- [ ] Approved — implement now
- [ ] Approved — schedule for a later milestone
- [ ] Rejected — recorded in the issue thread with reasoning
- [ ] Deferred — reason and revisit date recorded
