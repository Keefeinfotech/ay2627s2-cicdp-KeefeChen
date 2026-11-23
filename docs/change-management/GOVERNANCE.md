# Change Governance — CCB and CAB

**Version:** 1.0 · **Created:** 22 November 2026 · **Owner:** Release owner
**Purpose:** define who approves what, and when. The process steps live in
[change-management-process.md](change-management-process.md); this document adds
the decision authorities (CCB vs CAB) and their evidence records.

## 1. Boards and authority

| Board | Full name | Scope | Membership (current) | Cadence | Output |
|---|---|---|---|---|---|
| **CCB** | Change Control Board | Project/design changes: requirements, user stories, architecture, MongoDB schema, API contracts, CI configuration, scope changes | Project owner (requester + evaluator); optional independent reviewer | Sprint boundary or on demand | `CCB-YYYYMMDD-nn` decision on the change issue |
| **CAB** | Change Advisory Board | Production deployment approvals, release go/no-go, emergency changes, rollback decisions | Release owner + on-call/operator; optional stakeholder | Before each production release; within 1 working day for emergencies | `CAB-YYYYMMDD-nn` decision in release evidence / change log |

Both boards are one person wearing multiple hats in this solo project. The
process exists so the decision is **written down and linked**, not to imply a
committee that does not exist.

## 2. Change categories and routing

| Type | Definition | Examples | Approval route | Evidence |
|---|---|---|---|---|
| **Standard** | Pre-approved, low risk, reversible, no design/contract impact | Doc typo, dependency patch bump, test-only change | Normal PR + green CI; no board record needed | PR + CI run |
| **Normal** | Cross-module, contract/schema/security/deployment impact | Auth changes, MongoDB schema change, API contract change, pipeline change | CCB decision first, then PR + all gates, then CAB go/no-go for deploy | `CCB-*` on issue; `CAB-*` in release evidence |
| **Emergency** | Production defect needing immediate fix | Auth bypass, data loss, health check failing | Cut `hotfix/*` from `main`; fix + security/backend suites + CI (never skipped); CAB **retro-approval within 1 working day** | `CAB-*` + incident note + changelog within 1 day |

The change request form (`.github/ISSUE_TEMPLATE/change_request.md`) carries the
`Change type` field; the priority (Critical/High/Medium/Low) determines urgency
but does not replace the type.

## 3. Decision record template

Copy into the issue (CCB) or release evidence (CAB):

```markdown
### CAB-20261122-01
- Change / release: <issue or tag>
- Type: Standard | Normal | Emergency
- Decision: Approved | Approved with conditions | Rejected | Deferred
- Conditions / residual risks: <list; reference DEFECT_LOG IDs>
- Gates reviewed: <CI run URL, coverage, smoke result>
- Rollback plan: <LAST_GOOD_SHA or prior tag; rollback runbook link>
- Decision by / date: <name, timestamp>
```

## 4. Rollback readiness (mandatory for Normal and Emergency)

1. `LAST_GOOD_SHA` is recorded by `deploy-production.yml` after every successful smoke run.
2. `.github/workflows/rollback.yml` redeploys that exact SHA via Render API,
   polls `/api/health` and reruns `scripts/smoke-test.mjs`.
3. `docs/deployment/ROLLBACK_RUNBOOK.md` covers steps, data migration reversal
   and post-rollback actions. Rehearse against staging at least once per release
   cycle — note that the production rehearsal remains an open manual gate.
4. A CAB decision is invalid unless it names the rollback target.

## 5. Evidence and auditability

- Every CCB/CAB decision ID must appear in `docs/change-management/change-log.md`
  and in the relevant `RELEASE_EVIDENCE_*` file.
- The required GitHub Environment reviewers must be configured for `production`
  (and `approval` if used). Until then, the CAB approval is a documented record
  rather than an enforced workflow gate — state that explicitly in the evidence.
- Security and privacy gates G8–G10 in
  `../compliance/NFR_RELEASE_GATES.md` cannot be waived by either board.
- Changes to this document follow the standard PR + CCB decision route.
