# Auxilia Project Plan

Status: living proposal for the NP-S1 sprint and the wider Auxilia roadmap.
Owner: Keefe Chen. Last updated: 3 November 2026.

## Status key

| Label | Meaning |
|-------|---------|
| **Implemented** | Available in the repository and covered by automated tests. |
| **Sprint 1** | Delivered with this document; merge and Jira evidence pending. |
| **Planned** | Agreed direction with a defined phase, not built yet. |
| **Exploration** | Investigation or spike; no delivery commitment. |
| **Deferred** | Explicitly out of scope for the current release. |

Nothing labelled Planned, Exploration, or Deferred should be described to
stakeholders as working software.

## 1. Executive summary

Auxilia is an offline-first academic task manager that helps students turn a
course rubric into a realistic, trackable study plan. The current release
delivers the individual workspace: local tasks, priorities, courses, due dates,
XP, achievements, optional accounts, and a protected AI assistant endpoint.

The next product step is a **Group workspace** where student teams share a
roadmap and assignments, followed by an **AI Rubric-to-Roadmap** workflow that
proposes milestones and tasks from an assessment rubric. Both features are
**planned**; this document defines them so the design, permissions, data model,
and evaluation criteria are agreed before implementation.

## 2. Vision and objectives

**Vision.** Every student can answer three questions at a glance: what is due,
what matters most, and what to do next.

**Objectives for the next two releases.**

1. Reduce missed deadlines through clear due-today and overdue signals.
2. Make individual planning fast enough to use daily, including offline.
3. Let a group share one plan without losing individual accountability.
4. Convert rubric criteria into an editable roadmap while keeping the student
   in control of every AI-generated suggestion.
5. Protect student data by keeping tasks local by default and limiting what is
   sent to any AI provider.

**Non-goals for this release.** Replacing an institution's LMS, automatically
grading students, native mobile push notifications, and multi-institution
administration.

## 3. Current scope and status

### Implemented

- Local task CRUD with title, notes, priority, due date, reminder metadata,
  completion state, XP, and achievements.
- Course/subject tags, search across title/notes/course, status filtering,
  overdue filtering, pagination, and undo for delete and completion.
- Due-today and overdue dashboard counts.
- Versioned local storage (`auxilia.tasks.v2.*`) with one-way migration from the
  legacy v1 key and safe handling of corrupt or newer data.
- Guest mode, signup/login, secure session storage, session restore at launch,
  and named application routes.
- A persisted first-launch onboarding introduction, separate onboarding,
  sign-in, and registration screens, bundled Inter typography, and a consistent
  mobile-first design system across the dashboard, editor, assistant, and
  profile surfaces.
- Protected backend AI endpoint using a mock provider, JWT authentication,
  bcrypt password hashing, input validation, rate limits, and CORS allowlisting.
- CI: formatting, analysis, backend typecheck/build/tests, frontend tests, a 60%
  frontend line-coverage gate, backend coverage thresholds, Trivy scan, and a web
  release build.
- Documentation: privacy notice, NFR release gates, release checklist,
  dependencies, enterprise auth notes, and this plan.

### Sprint 1 delivered with this document

These changes are implemented and tested on the sprint branch; Jira evidence and
merge are the remaining release steps.

- Course tags and course-aware search.
- Due-today/overdue dashboard awareness and an Overdue filter.
- Undo for deletion and completion without double-awarding XP.
- Storage schema v2 and legacy migration tests.
- Session restore splash gate and route centralisation.
- Frontend coverage gate, pull-request template, and Vitest ESM config cleanup.

### Planned, exploration, and deferred

| Item | Status | Target |
|------|--------|--------|
| Group workspace (shared tasks, roles, invitations) | Planned | Phase 3 |
| AI rubric-to-roadmap with student approval | Planned | Phase 4 |
| Server-side task sync across devices | Planned | After group model |
| Scheduled local notifications | Planned | With notification spike |
| Real LLM provider behind the existing AI endpoint | Exploration | Phase 4 spike |
| Offline conflict resolution for shared tasks | Exploration | Phase 3/4 |
| LMS / rubric import integrations | Deferred | Post-release |
| File export/import of task data | Deferred | Post-release |
| Dashboard quick due presets and pull-to-refresh | Deferred | Next UX pass |
| Google/GitHub OAuth | Deferred | Requires provider configuration plus backend callback endpoints |
| Password reset | Deferred | Requires an email provider and reset-token endpoints |
| Local task-data encryption at rest | Deferred | Requires key management and migration |
| Institutional analytics and teacher dashboards | Deferred | Not in current scope |

## 4. System structure and modules

```
Flutter client
├── core           design tokens/theme, shared widgets, API client, endpoints,
│                  formatters, named routes and typed route arguments
├── features
│   ├── onboarding      first-launch introduction and completion store
│   ├── authentication  login, signup, startup gate, auth/session, captcha
│   ├── home            dashboard, task model/store/repository, task editor,
│   │                   validation, gamification
│   ├── assistant       chat screen, composer, bubbles, assistant API service
│   └── profile         profile and local-data actions sheet
├── app.dart       MaterialApp shell, themes, onGenerateRoute
├── main.dart      ProviderScope entry point
└── legacy paths   screens/widgets/models/services/routing/theme/utils are
                   thin re-export shims for backward compatibility

Express API
├── routes         /api/auth, /api/ai, /api/health
├── middleware     authentication, validation, rate limits, errors, CORS/helmet
├── services       password hashing, JWT, AI provider abstraction
└── persistence    MongoDB user collection

GitHub Actions
└── security scan, backend checks, frontend checks, coverage gates, build
```

**Individual workspace (Implemented).** Tasks belong to an owner key (`local`
for guests, account email for signed-in users) and stay on the device.

**Group workspace (Planned).** A shared project with members, roles, a shared
roadmap, per-item assignees, and an activity trail. It requires new backend
entities and APIs; none exist today.

**AI rubric-to-roadmap (Planned).** A guided workflow in the client, backed by a
new authenticated API that returns structured proposals rather than free text.
The current AI endpoint is a mock and must not be presented as doing this.

## 5. Individual and group workspaces

### Individual workspace

- Private by default; no task content leaves the device.
- Fast capture, priority, course tag, due date, notes, completion, XP.
- Deadline awareness and undo protect against accidental loss.
- Works fully offline; authentication is optional except for the assistant.

### Group workspace (Planned)

**Purpose.** Student teams plan a shared assessment while keeping individual
ownership visible.

**Roles.**

| Role | Capabilities |
|------|--------------|
| Owner | Manage group, members, roles, and deletion; approve roadmap changes. |
| Editor | Create/edit shared tasks and roadmap items; assign members. |
| Member | Complete assigned items; comment; propose changes. |
| Viewer | Read-only access for supervisors or external reviewers. |

**Core flows.**

1. Create a group and invite members by email or shareable invite code.
2. Import an individual plan or generate a rubric roadmap into the group.
3. Assign owners and due dates; everyone sees the same plan.
4. Members update status; the dashboard shows group progress and at-risk work.
5. The owner resolves conflicts and removes stale members.

**Explicit boundaries.** Group data is not part of the current local-only
release. Existing individual tasks do not automatically become group tasks, and
no group API or schema is implemented yet.

## 6. AI Rubric-to-Roadmap workflow (Planned)

**Input.** A rubric document or pasted text, assessment due date, available
study hours, and optional course context. File upload is deferred; the first
release accepts pasted text and manual criteria entry.

**Pipeline.**

1. **Extract** criteria, weights, descriptors, and evidence requirements.
2. **Normalise** into a structured `Rubric` with weighted `Criterion` records.
3. **Draft** milestones and tasks that map to each criterion, with estimates.
4. **Schedule** work backwards from the due date, respecting student capacity.
5. **Review** in a side-by-side UI: criterion coverage, warnings, and editable
   tasks. The student can accept, edit, or reject each suggestion.
6. **Commit** only approved items to the workspace, with a provenance link back
   to the rubric and a visible "AI-assisted" label.

**Human-in-the-loop rules.**

- AI output is a proposal, never an automatic grade or final plan.
- The student approves the roadmap before tasks are created.
- Low-confidence or missing rubric evidence is surfaced, not hidden.
- Every generated item can be traced to a criterion and prompt version.
- Group roadmaps require owner approval for assignment changes.

**Provider strategy.** The provider stays behind an interface. A real provider
is **Exploration**; the current mock must remain clearly labelled until a
provider, cost model, and data-processing agreement are approved.

## 7. Review, approval, and governance

- **Student review.** Required before any AI-generated task is saved.
- **Group owner approval.** Required for membership, role changes, and
  reassignment of shared work.
- **Product review.** Each phase closes with a demo, test evidence, accessibility
  check, and updated documentation.
- **Jira evidence.** Each story links its pull request, CI run, test counts, and
  screenshots; a story is not Done until the PR is merged to `main`.
- **Change control.** Scope changes go through the project plan status table and
  must name what is being deferred.

## 8. Delivery phases and priorities

### Phase 1 — Individual workspace foundation (Implemented)

Tasks, XP, local persistence, guest mode, authentication, assistant shell,
accessibility, and CI.

### Phase 2 — Sprint 1 enterprise hardening (Sprint 1)

Course tags, deadline awareness, undo, storage migration, session restore,
routing, PR hygiene, and coverage gate. Priority: close the six NP-S1 stories with
test evidence.

### Phase 3 — Group workspace (Planned)

1. Group and membership schema; invite and role APIs.
2. Shared task model with assignee; group dashboard and filters.
3. Activity feed and owner controls.
4. Offline read support; write conflict handling moves to Exploration.
5. Permissions tests (owner/editor/member/viewer) and privacy review.

### Phase 4 — AI rubric-to-roadmap (Planned)

1. Rubric parser and structured schema.
2. Proposal API and provider interface; mock implementation first.
3. Review and approval UI; provenance and AI labels.
4. Group integration; capacity-aware scheduling.
5. Evaluation with real course rubrics and a small student cohort.

### Phase 5 — Sync and notifications (Planned / Exploration)

Server-side task sync is planned after the group model. Scheduled notifications
need a platform spike. Conflict resolution and real-time collaboration remain
Exploration.

## 9. Architecture and data model

### Current entities (Implemented)

| Entity | Fields | Storage |
|--------|--------|---------|
| `User` | id, name, email, password hash, timestamps | MongoDB |
| `Task` | id, title, notes, course, priority, status, due/reminder/completed timestamps, XP flag | Device preferences, versioned envelope |
| `Session` | token, email, name | Platform secure storage |

### Planned entities

| Entity | Purpose | Notes |
|--------|---------|-------|
| `Group` | Shared workspace | Owner, title, course, archived flag |
| `GroupMember` | Membership and role | Unique group/user pair; role enum |
| `GroupTask` | Shared task | Links to group, assignee, rubric item |
| `Rubric` | Parsed assessment | Versioned source text and checksum |
| `Criterion` | Weighted rubric row | Weight, descriptor, evidence |
| `Roadmap` | Approved plan | Group or individual owner |
| `RoadmapItem` | Milestone/task proposal | Criterion link, estimate, status |
| `Invite` | Pending membership | Token hash, expiry, role |
| `ActivityEvent` | Audit trail | Actor, action, target, timestamp |

### Planned API surface

```
POST   /api/groups
GET    /api/groups
POST   /api/groups/:id/invites
POST   /api/groups/:id/members
PATCH  /api/groups/:id/members/:userId
GET    /api/groups/:id/tasks
POST   /api/groups/:id/tasks
PATCH  /api/groups/:id/tasks/:taskId
POST   /api/rubrics/parse
POST   /api/rubrics/:id/roadmap-proposals
POST   /api/roadmaps/:id/approve
```

### Data consistency

- Local writes are validated, persisted, then reflected in the UI; a failed
  write keeps the previous state and surfaces an error.
- The v2 envelope carries an explicit schema version; unknown newer versions are
  rejected instead of silently corrupted.
- Planned server writes use optimistic concurrency (`version` field), idempotency
  keys for retries, and a single transactional path per group mutation.
- Undo restores the original record, including XP and timestamps, rather than
  recreating a partial copy.

## 10. Security, privacy, permissions, and offline behaviour

### Security

- JWT bearer authentication; bcrypt hashing with clamped cost.
- Request validation, body-size limits, rate limits, Helmet, and a CORS
  allowlist.
- Secrets only in environment variables; `.env` is never committed.
- Tokens in platform secure storage, never in shared preferences or source.
- Authentication is email/password only. OAuth and password reset are deferred
  and must not be presented in the client as working flows.
- CI runs Trivy and fails on type, test, analysis, and coverage regressions.

### Privacy

- Tasks stay on the device in the current release. Accounts store only name
  (optional), email, and password hash.
- AI requests contain only the message the student sends; no task list is
  uploaded automatically.
- Planned rubric processing must define retention, provider data handling, and a
  deletion path before launch. See `docs/compliance/PRIVACY.md`.
- Generated roadmaps are labelled AI-assisted and remain editable.

### Permissions (planned)

- Every group query is scoped to verified membership; role checks happen on the
  server, not only in the client.
- Invite tokens are hashed, expire, and are single-use.
- Owners cannot silently remove audit history; deletions are recorded.
- A member sees only groups they belong to and only fields allowed by their role.

### Offline behaviour

- Individual tasks are local-first and fully usable without a network.
- Group reads will be cached; offline writes queue locally and reconcile when
  connectivity returns.
- Conflict policy is **Exploration**: last-write-wins is acceptable only for
  low-risk metadata; completion and assignment conflicts need an explicit
  resolution UI.
- AI roadmap generation requires a network connection; the review and editing
  steps remain local once a proposal is received.

## 11. Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| AI produces plausible but wrong rubric mappings | Poor plan, lost trust | Require student approval, show criterion evidence, flag low confidence, keep prompts versioned |
| Group permissions leak data | Privacy breach | Server-side membership checks, deny-by-default tests, audit events |
| Offline edits conflict | Lost work | Durable local queue, explicit conflict UI, optimistic version checks |
| Scope expands beyond the sprint | Missed deadlines | Status table, phase gates, defer list agreed up front |
| Storage migration corrupts local data | Data loss | Versioned envelope, backup-before-write, legacy fallback, migration tests |
| Real AI cost or provider limits | Budget and reliability | Provider abstraction, quotas, mock-first development, cost caps |
| Accessibility regressions | Unusable for some students | Semantics tests, 200% text-scale test, manual review each UI phase |
| Unauthenticated deploy or weak secrets | Account compromise | Startup validation, secret scanning, documented environment contract |

## 12. Outcomes and evaluation

### Success measures

- **Individual:** weekly active use, tasks created per week, on-time completion
  rate, and reduction in overdue tasks after the deadline-awareness release.
- **Group:** percentage of shared tasks with an assignee, group completion rate,
  and owner-reported planning time saved.
- **AI roadmap:** percentage of proposals accepted with edits, criterion coverage,
  and student-rated usefulness. AI accuracy is measured against manually
  reviewed rubrics, not presented as a grade.
- **Quality:** CI green rate, coverage gate, crash-free sessions, and
  accessibility checks at 200% text scale.
- **Privacy:** zero task-content uploads without explicit student action; every
  AI request auditable by prompt version.

### Evaluation plan

1. Automated tests and CI evidence for every merged story.
2. Moderated usability sessions with 5–8 students on individual planning.
3. A small rubric pilot (one course, one group) before wider release.
4. Before/after measures for overdue work and planning time.
5. A documented decision at each phase: continue, adjust, or defer.

## 13. Immediate next steps

1. Merge the Sprint 1 branch and attach PR, CI, and test evidence to NP-S1.
2. Validate the group workspace schema and permissions with a design review.
3. Spike rubric parsing with three real course rubrics.
4. Select the AI provider path only after privacy and cost review.
5. Keep this plan current: move items between Implemented, Planned, Exploration,
   and Deferred as evidence changes.
