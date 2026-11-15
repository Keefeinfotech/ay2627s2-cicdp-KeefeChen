# Auxilia Project Plan

Status: living proposal for the NP-S1 sprint and the wider Auxilia roadmap.
Owner: Keefe Chen. Last updated: 15 November 2026.

Implementation update (15 November 2026): the group workspace, invitations,
shared assignments, offline change queue, retry/backoff, conflict handling,
sync status, server-side task sync, in-app reminders, and password reset are
implemented and covered by automated tests. See
`docs/reports/USER_STORY_CICD_REPORT.md` for the story-by-story evidence and
remaining release gates, and `docs/planning/USER_STORIES.md` for the
acceptance-criteria catalogue.

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
XP, achievements, optional accounts, server-side sync, group workspaces, and a
protected AI assistant endpoint.

The group workspace is implemented (groups, invitations, roles, shared
assignments, progress rollups, sync and conflict handling). The next product
step is an **AI Rubric-to-Roadmap** workflow that proposes milestones and tasks
from an assessment rubric; backend CRUD scaffolding for rubrics and roadmaps
exists, but the AI generation and review flow is **planned**, not built. This
document defines the workflow so the design, permissions, data model, and
evaluation criteria are agreed before implementation.

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
- Password reset end-to-end (request, emailed link, single-use token) and MFA
  (TOTP) on the backend.
- Group workspaces: CRUD, hashed single-use invitations with seven-day expiry,
  roles and membership checks on the server, shared assignments, and group
  progress rollups.
- Server-side task sync for signed-in users: durable offline change queue with
  retry/backoff and dead-lettering, background sync on launch/resume/reconnect,
  app-wide sync status banner, whole-task conflict resolution (Keep mine / Use
  server).
- In-app reminders (banners, snooze, complete) and a dedicated reminders hub;
  no OS-level scheduling yet.
- A persisted first-launch onboarding introduction, separate onboarding,
  sign-in, and registration screens, bundled Inter typography, and a consistent
  mobile-first design system across the dashboard, editor, assistant, and
  profile surfaces.
- Protected backend AI endpoint using a mock provider (OpenAI-compatible
  provider supported), JWT authentication, bcrypt password hashing, input
  validation, rate limits, and CORS allowlisting.
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
| Group workspace (shared tasks, roles, invitations) | **Implemented** | Shipped (Phase 3) |
| Server-side task sync across devices | **Implemented** | Shipped (offline queue + conflict resolution) |
| Offline conflict resolution (whole-task) | **Implemented** | Shipped; field-level merge remains Exploration |
| Password reset | **Implemented** | Request/email/reset flow (SMTP required in production) |
| MFA (TOTP) | **Implemented** (backend) | Client enrolment UI not yet built |
| AI rubric-to-roadmap with student approval | Planned | Phase 4 (backend CRUD scaffolding exists) |
| OS-level scheduled notifications | Planned | Requires platform notification spike |
| Real LLM provider behind the existing AI endpoint | Exploration | Phase 4 spike |
| Refresh-token rotation / server-side session store | Planned | Hardening phase |
| LMS / rubric import integrations | Deferred | Post-release |
| File export/import of task data | Deferred | Post-release |
| Dashboard quick due presets and pull-to-refresh | Deferred | Next UX pass |
| Google/GitHub OAuth | Deferred | Requires provider configuration plus backend callback endpoints |
| Local task-data encryption at rest | Deferred | Requires key management and migration |
| Account deletion in app | Deferred | Post-release |
| Institutional analytics and teacher dashboards | Deferred | Not in current scope |

## 4. System structure and modules

```
Flutter client
├── core           design tokens/theme, shared widgets, API client, endpoints,
│                  formatters, named routes and typed route arguments
├── features
│   ├── onboarding      first-launch introduction and completion store
│   ├── authentication  login, signup, forgot/reset password, startup gate,
│   │                   auth/session, captcha
│   ├── home            dashboard, task model/store/repository, task editor,
│   │                   validation, gamification
│   ├── task_management quick-add parser, task breakdown, use cases
│   ├── assistant       chat screen, composer, bubbles, assistant API service
│   ├── groups          group CRUD, invitations, assignment UI
│   ├── projects        project workspaces with progress roll-up
│   ├── calendar        calendar views, event editor, schedule analysis
│   ├── reminders       in-app reminder host, reminder hub screen
│   ├── reports         charts and progress snapshots
│   ├── sync            offline queue, sync status banner and centre
│   └── profile         profile and local-data actions sheet
├── app.dart       MaterialApp shell, themes, onGenerateRoute
├── main.dart      ProviderScope entry point
└── legacy paths   screens/widgets/models/services/routing/theme/utils are
                   thin re-export shims for backward compatibility

Express API
├── routes         /api/auth, /api/ai, /api/health, /api/tasks, /api/groups,
│                  /api/invitations, /api/calendar, /api/reminders, /api/admin,
│                  /api/sync, /api/reports, /api/rubrics, /api/roadmaps,
│                  /api/audit, /api/metrics, /api/progress
├── middleware     authentication, validation, rate limits, errors, CORS/helmet,
│                  Prometheus metrics
├── services       password hashing, JWT (access + refresh), AI provider
│                  abstraction, invitation tokens, audit logging
└── persistence    MongoDB collections with $jsonSchema validators

GitHub Actions
└── security scan, backend checks, frontend checks, coverage gates, E2E
    (Playwright), and a web release build
```

**Individual workspace (Implemented).** Tasks belong to an owner key (`local`
for guests, account email for signed-in users). Guest workspaces stay on the
device; signed-in users sync through the backend with a durable offline queue.

**Group workspace (Implemented).** Groups with owner/member roles, hashed
single-use invitations, shared assignment of tasks to members, and a shared
progress roll-up. Remaining gaps: no assignee notifications, and the backend
groups module is excluded from the coverage gate until controller/integration
tests are added.

**AI rubric-to-roadmap (Planned).** A guided workflow in the client, backed by a
new authenticated API that returns structured proposals rather than free text.
The current AI endpoint is a mock and must not be presented as doing this.

## 5. Individual and group workspaces

### Individual workspace

- Private by default; no task content leaves the device.
- Fast capture, priority, course tag, due date, notes, completion, XP.
- Deadline awareness and undo protect against accidental loss.
- Works fully offline; authentication is optional except for the assistant.

### Group workspace (Implemented)

**Purpose.** Student teams plan a shared assessment while keeping individual
ownership visible. Shipped: group CRUD with owner permissions, hashed
invitations with seven-day expiry and an email-bound accept flow, server-side
membership and assignee checks, and a group progress roll-up.

**Roles as implemented.**

| Role | Capabilities |
|------|--------------|
| Owner | Create/manage group, archive it, invite members, assign shared tasks, view progress. |
| Member | See group tasks assigned to them, complete them, and view group progress. |

Editor and Viewer roles and per-item commenting remain planned; the current
implementation models owner vs. member only.

**Core flows as implemented.**

1. Create a group; invite members by email; the invite link is single-use,
   hashed at rest, and expires after seven days.
2. Assign group tasks to members; the server rejects assignees who are not
   members (`ASSIGNEE_NOT_IN_GROUP`) and requires the group context
   (`ASSIGNEE_REQUIRES_GROUP`).
3. Members update status; the group progress endpoint reports completion.
4. Changes queue offline and sync on reconnect with whole-task conflict
   resolution (Keep mine / Use server).

**Explicit boundaries.** Individual tasks do not automatically become group
tasks. Invite emails require SMTP to be delivered; without it a manual
one-time code fallback is shown. There are no assignee notifications yet.
Group flows are covered by repository and service tests; group
controller/integration coverage is still excluded from the backend gate.

## 6. AI Rubric-to-Roadmap workflow (Planned)

Status note (15 November 2026): backend CRUD scaffolding for rubrics and
roadmaps exists (`modules/rubrics`, `modules/roadmaps`, with validation) but
is excluded from the coverage gate and is not wired to any client flow. The
AI extraction/proposal steps, the review UI, and provenance labels described
below are **not built**. The current AI endpoint is a mock and must not be
presented as doing this.

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

### Phase 2 — Sprint 1 enterprise hardening (Implemented)

Course tags, deadline awareness, undo, storage migration, session restore,
routing, PR hygiene, and coverage gate. Closed with test evidence.

### Phase 3 — Group workspace (Implemented; scope trimmed)

Shipped: group and membership schema; hashed invite APIs; shared task model
with assignee; server-side membership/assignee checks; group progress roll-up;
groups UI; invitation accept flow. Not shipped: Editor/Viewer roles, comment
threads, activity feed in the client, and group controller/integration coverage
(module remains excluded from the backend coverage ratchet).

### Phase 4 — AI rubric-to-roadmap (Planned)

1. Rubric parser and structured schema.
2. Proposal API and provider interface; mock implementation first.
3. Review and approval UI; provenance and AI labels.
4. Group integration; capacity-aware scheduling.
5. Evaluation with real course rubrics and a small student cohort.

### Phase 5 — Sync and notifications (Implemented / Planned)

Server-side sync shipped: durable offline queue, retry/backoff with
dead-lettering, launch/resume/reconnect triggers, app-wide status banner and
whole-task conflict resolution. Still open: OS-level scheduled notifications
(requires a platform spike and permission UX) and field-level merge. Real-time
collaboration remains Exploration.

## 9. Architecture and data model

### Current entities (Implemented)

| Entity | Fields | Storage |
|--------|--------|---------|
| `User` | id, name, email, password hash, role, timestamps | MongoDB (two schemas registered — see report) |
| `Task` | id, title, notes, course, priority, status, due/reminder/completed timestamps, XP flag | Device preferences, versioned envelope; mirrored to MongoDB for signed-in users |
| `Session` | token, email, name | Platform secure storage |
| `Group` | id, name, course, owner, archived flag, timestamps | MongoDB |
| `GroupMember` | group, user, role, timestamps | MongoDB |
| `Invite` | group, email, token hash, role, expiry, status | MongoDB |
| `AuditEvent` | actor, action, target, timestamp | MongoDB (`modules/audit`) |
| `CalendarEvent` | title, start/end, type, owner | MongoDB |
| `Reminder` | userId, message, dueAt, completed | MongoDB (client uses the offline-first task model) |

### Scaffolded entities (backend CRUD exists; not wired to any client flow)

| Entity | Purpose | Notes |
|--------|---------|-------|
| `Rubric` | Parsed assessment | Backend CRUD + validation; AI extraction not built |
| `Criterion` | Weighted rubric row | Backend schema present |
| `Roadmap` | Approved plan | Backend CRUD + validation; no approval flow |
| `RoadmapItem` | Milestone/task proposal | Backend schema present; no UI |

### Implemented API surface

```
GET    /api/tasks              POST   /api/tasks
GET    /api/tasks/:taskId      PATCH  /api/tasks/:taskId   DELETE /api/tasks/:taskId
GET    /api/sync/changes       (client writes via /api/tasks; change feed for pull sync)
POST   /api/groups             GET    /api/groups
GET    /api/groups/:groupId/progress
POST   /api/invitations        POST   /api/invitations/accept
POST   /api/auth/{signup,login,logout,refresh,forgot-password,reset-password}
GET    /api/health             GET    /metrics (token-guarded)
Full module list: groups, invitations, calendar, reminders, admin, feedback,
reports, progress, audit, users, rubrics, roadmaps, sessions (study sessions),
AI assistant — see `backend/src/app.ts` mounts.
```

### Scaffolded or planned API surface

```
POST   /api/rubrics/parse          (rubric CRUD exists; AI parse not built)
POST   /api/rubrics/:id/roadmap-proposals   (not built)
POST   /api/roadmaps/:id/approve            (roadmap CRUD exists; approval not built)
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
- Authentication is email/password (plus TOTP MFA on the backend). OAuth is
  deferred; password reset is implemented and requires SMTP in production.
- CI runs Trivy and fails on type, test, analysis, and coverage regressions.

### Privacy

- Tasks stay on the device in the current release. Accounts store only name
  (optional), email, and password hash.
- AI requests contain only the message the student sends; no task list is
  uploaded automatically.
- Planned rubric processing must define retention, provider data handling, and a
  deletion path before launch. See `docs/compliance/PRIVACY.md`.
- Generated roadmaps are labelled AI-assisted and remain editable.

### Permissions (implemented for groups; planned for finer roles)

- Every group query is scoped to verified membership; role checks happen on the
  server, not only in the client.
- Invite tokens are hashed (SHA-256), expire after seven days, are single-use,
  and are bound to the invitee's email.
- Owners cannot silently remove audit history; the backend records audit events
  (`modules/audit`).
- A member sees only groups they belong to and only fields allowed by their role.

### Offline behaviour

- Individual tasks are local-first and fully usable without a network; signed-in
  workspaces sync through the backend when connected.
- Offline writes queue locally and replay on reconnect; permanent failures
  dead-letter after three attempts and can be discarded from the Sync centre.
- Conflict policy (implemented): whole-task resolution with an explicit UI
  ("Keep mine" / "Use server"); field-level three-way merge remains Exploration.
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

1. Execute the release (cut `v1.0.0`, exercise `release.yml`, evidence the
   manual NFR gates) — closes NP-16.
2. Add group controller/integration tests and lift the backend groups module
   out of the coverage exclusion; raise, never lower, the ratchet.
3. Spike rubric parsing with three real course rubrics.
4. Select the AI provider path only after privacy and cost review.
5. Keep this plan current: move items between Implemented, Planned, Exploration,
   and Deferred as evidence changes. Acceptance-criteria status for every story
   lives in `docs/planning/USER_STORIES.md`.
