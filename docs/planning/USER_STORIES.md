# Auxilia — User Stories and Acceptance Criteria

Date: 15 November 2026 · Owner: Keefe Chen · Status: living document

This catalogue supersedes the Jira-key-only board listing for day-to-day work.
Every story below is written in the standard
`As a <role>, I want <goal>, so that <benefit>` format with testable
acceptance criteria, in priority order.

- `NP-*` — original Jira board keys (kept verbatim for traceability).
- `AUX-*` — capabilities that shipped without a board story; catalogued here
  on 15 November 2026 so the board reflects reality.
- `BACKLOG-*` — agreed gaps, **not** implemented. Nothing marked Backlog or
  Planned may be presented as working software.

Statuses: **Done** (in repository, tested) · **Partial** (works, release gates
open) · **Planned** (Phase 3/4 items with defined scope) · **Backlog** (agreed,
unscheduled).

Personas

| Persona | Description |
|---------|-------------|
| **Alex** — the student | Diploma student juggling coursework; primarily offline, occasionally on campus Wi-Fi or home broadband. |
| **Priya** — the group lead | Alex's peer who coordinates a group assessment in a shared workspace. |
| **Sam** — the administrator | SP IT/demonstrator account that inspects users and platform health in the admin console. |

Definition of Done (applies to every story)

1. Code merged to the default branch via reviewed pull request.
2. Acceptance criteria covered by automated tests at the appropriate layer.
3. CI quality gates green (format, analyze, typecheck, tests, coverage gates).
4. Accessible (semantic labels, ≥200% text-scale usable or automated check).
5. Documentation/report updated; Jira key linked to PR and CI run.

---

## Epic NP-1 — Foundation and application shell

### NP-6 — Set up Flutter project and Git repository
**As** the developer, **I want** a Flutter project in a versioned Git repository
with a defined branching model, **so that** all work is reviewable and
traceable.

- Priority: Must · Points: 2 · Status: Done

**Acceptance criteria**
- Given a fresh clone, when `flutter pub get` and the CI pipeline run, then the
  app compiles and all configured checks execute without manual steps.
- Given a push to a feature branch, then a pull request must pass the
  `ci-summary` required gate before merge.

**Traceability:** `.github/workflows/ci.yml`, `docs/release/BRANCHING.md`,
PR template, Conventional Commits enforced by the `pr-conventions` job.

### NP-7 — Establish app navigation and layout
**As** Alex, **I want** a consistent navigation shell (bottom bar on phones,
rail on tablets, sidebar on desktops), **so that** I can reach any area of the
app in one tap without losing my place.

- Priority: Must · Points: 5 · Status: Done

**Acceptance criteria**
- Given a phone (<600 px), then five destinations appear in the bottom
  navigation; given a tablet (≥600 px), a navigation rail; given a desktop
  (≥1024 px), a labelled sidebar.
- Given a signed-out user, the Admin destination is hidden; deep-linking to
  `/admin` shows a sign-in placeholder, not the console.
- Given a screen wider than 1024 px, warm-started pages keep their scroll and
  form state (IndexedStack) when switching destinations.

**Traceability:** `lib/core/layout/app_shell.dart`, `core/widgets/app_navigation.dart`,
`test/core/app_shell_test.dart`, `test/visual/`.

### NP-18 — Set up Flutter and Dart project environment
**As** the developer, **I want** a reproducible Flutter/Dart toolchain with
pinned versions, **so that** builds are identical locally and in CI.

- Priority: Must · Points: 1 · Status: Done

**Acceptance criteria**
- Given the repository, when CI starts, then Flutter 3.47.8 is installed and
  `pub get --enforce-lockfile` succeeds.
- Given a release tag, the release workflow verifies tag == `backend/package.json`
  == `frontend/pubspec.yaml` versions before packaging.

**Traceability:** CI `frontend` job, `release.yml`, `jenkins/Dockerfile`.

### NP-50 — Navigation router / bottom navigation bar
**As** Alex, **I want** a single named-route table with typed arguments, **so
that** deep links and back-stack behaviour are predictable and testable.

- Priority: Must · Points: 3 · Status: Done

**Acceptance criteria**
- Given a named route with missing/invalid arguments, then the app falls back
  to the startup gate instead of a blank screen.
- Given a signed-out deep link to `/assistant`, `/reminders` or `/groups`, the
  screen renders a session-aware (or explicitly guest) context rather than
  crashing.
- Given `/home` with no arguments, the guest workspace is used deterministically.

**Traceability:** `core/routing/app_router.dart` (`AppRoutes`, `HomeArgs`,
`AssistantArgs`, `RemindersArgs`, `GroupsArgs`, `AdminArgs`),
`test/core/app_shell_test.dart`, `test/core/api_client_test.dart`.

> Improvement landed 15 November 2026: `/reminders` and `/groups` now accept
> typed args carrying a live `TaskStore` and `Session`, so signed-in deep
> links share the shell's in-memory state instead of constructing a blank
> guest context.

### AUX-1 — Onboarding for first-time users *(untracked capability)*
**As** a first-time Alex, **I want** a short onboarding introduction, **so
that** I understand what the app does before creating an account.

- Priority: Should · Points: 3 · Status: Done

**Acceptance criteria**
- Given a fresh install, when the app launches, then onboarding is shown once
  and completion persists (`OnboardingStore`).
- Given onboarding reopened from Settings, then the system back button pops to
  the previous screen instead of restarting onboarding.

**Traceability:** `features/onboarding/`, `HomeArgs`/onboarding tests.

### AUX-2 — Optional account with secure session
**As** Alex, **I want** to use the app as a guest and optionally create an
account, **so that** my tasks sync without an account being mandatory.

- Priority: Must · Points: 5 · Status: Done

**Acceptance criteria**
- Given guest mode, tasks are stored locally and are never uploaded.
- Given valid credentials, signup/login returns a JWT access token; the
  refresh flow uses a single-flight silent renewal shared across API instances.
- Given a restarted app, the session is restored from secure storage (never
  shared preferences).
- Given a plaintext non-loopback `API_BASE_URL`, the app refuses to send
  credentials.

**Traceability:** `features/authentication/`, `core/network/api_client.dart`,
`integration_test/`, backend `tests/integration/auth*`.

### AUX-3 — Password reset
**As** Alex, **I want** to reset my password by email, **so that** I can
recover access without contacting support.

- Priority: Should · Points: 3 · Status: Done (SMTP required in production)

**Acceptance criteria**
- Given a registered email, when a reset is requested, then a single-use,
  time-limited token link is sent (or shown in the console in non-production
  without SMTP).
- Given an invalid/expired token, the reset screen rejects the submission with
  a safe error.
- Given a successful reset, the old password no longer authenticates.

**Traceability:** `features/authentication/screens/forgot_password_screen.dart`,
`reset_password_screen.dart`, backend `auth` module, `tests/integration/refresh`.

### AUX-4 — Multi-factor authentication (TOTP)
**As** Alex, **I want** to be able to protect my account with an authenticator
app, **so that** a leaked password alone cannot open my account.

- Priority: Could · Points: 5 · Status: Partial (backend complete; client
  enrolment UI missing — see BACKLOG-7)

**Acceptance criteria**
- Given MFA enabled, login requires a valid TOTP code.
- Given a wrong code, authentication fails with a generic error.

**Traceability:** backend `modules/auth/mfa*`, `otplib`, `qrcode`.

---

## Epic NP-2 — Core task management

### NP-8 — Create and view tasks
**As** Alex, **I want** to create tasks with a title, and see them in a list,
**so that** I can capture work the moment I think of it.

- Priority: Must · Points: 3 · Status: Done

**Acceptance criteria**
- Given a non-empty title, when saved, the task persists locally and appears in
  the list immediately, including offline.
- Given an empty title, the editor blocks submission with `Enter a task title`.
- Given 200% text scaling on a 360 px screen, the editor remains usable without
  clipped actions.

**Traceability:** `home/widgets/task_editor.dart`, `task_store.dart`,
`test/screens/home_screen_test.dart`, `test/task_validation*`.

### NP-9 — Edit, delete, and complete tasks
**As** Alex, **I want** to edit, delete and complete tasks, with undo, **so
that** mistakes are cheap and completion feels rewarding.

- Priority: Must · Points: 5 · Status: Done

**Acceptance criteria**
- Given a task, when completed, then XP is awarded once and never re-awarded on
  reopen/recomplete cycles.
- Given an accidental delete, undo restores the original record, including XP.
- Given an edit, the updated `updatedAt` is persisted and syncs when online.

**Traceability:** `task_store.dart`, `gamification.dart`, `test/services/task_store_test.dart`.

### NP-10 — Persist tasks using local storage
**As** Alex, **I want** my tasks stored on-device with a versioned schema,
**so that** the app works offline and upgrades never corrupt data.

- Priority: Must · Points: 3 · Status: Done

**Acceptance criteria**
- Given schema v1 data, the migration to `auxilia.tasks.v2.*` is one-way and
  preserves tasks.
- Given corrupt records in storage, unreadable entries are skipped instead of
  crashing the app.
- Given a newer unknown schema version, it is rejected rather than silently
  mangled.

**Traceability:** `home/data/task_repository.dart`, `task_store_test.dart`
(`detects newer schema versions`), migration tests.

### NP-29 — Task tags & priority organisation
**As** Alex, **I want** tags and priority on every task, **so that** I can
slice my workload by course and urgency.

- Priority: Must · Points: 3 · Status: Done

**Acceptance criteria**
- Given a task with tags, they are trimmed, whitespace-collapsed, de-duplicated
  case-insensitively, capped at eight (≤24 chars each), with the `#` prefix
  stripped.
- Given a tag filter, the list narrows to tasks carrying that tag.
- Given the editor, priority and deadline are visible on the task card without
  extra taps.

**Traceability:** `models/task.dart#normalizeTags`, `task_filter_bar.dart`,
`test/services/task_validation_test.dart`, `task_card.dart`.

### AUX-5 — Natural-language quick add *(untracked capability → NP-46)*
See **NP-46** below (implementation includes deterministic parsing of dates,
times and `#tags`).

### AUX-6 — Projects workspaces *(untracked capability)*
**As** Alex, **I want** to group tasks into projects with progress roll-ups,
**so that** a multi-week assessment feels like one unit of work.

- Priority: Should · Points: 5 · Status: Done

**Acceptance criteria**
- Given a project, its detail page shows member tasks, completion percentage
  and a roll-up status.
- Given a project with no tasks, an empty state explains how to add the first.

**Traceability:** `features/projects/`, `test/features/projects/`.

---

## Epic NP-3 — Dashboard and motivation

### NP-11 — Build student task dashboard
**As** Alex, **I want** a home dashboard that surfaces what is due and what
matters, **so that** I can plan in under a minute each morning.

- Priority: Must · Points: 5 · Status: Done

**Acceptance criteria**
- Given tasks exist, the dashboard shows due-today and overdue counts that
  update immediately when tasks change.
- Given no tasks, the empty state explains how to create the first one.
- Given 200% text scaling, the header and cards reflow without overflow.

**Traceability:** `home/screens/home_screen.dart`, `dashboard_header.dart`,
`test/screens/home_screen_test.dart` ("remains usable at 200% text scaling").

### NP-13 — Display task priorities and deadlines
**As** Alex, **I want** priorities and deadlines visible on every task, **so
that** urgency is obvious at a glance.

- Priority: Must · Points: 2 · Status: Done

**Acceptance criteria**
- Given a priority, the card shows a labelled badge (Low/Medium/High) with an
  accessible semantic label.
- Given an overdue task, it is visually flagged and the overdue filter lists it.
- Given a due-today task, the dashboard due-today count includes it.

**Traceability:** `task_card.dart`, `PriorityBadge` in `core/widgets/app_status_badge.dart`,
`reports` breakdowns, `test/widgets/task_card_test.dart`.

### NP-12 — Customizable avatar
**As** Alex, **I want** to pick an avatar and display name, **so that** the app
feels like mine.

- Priority: Should · Points: 2 · Status: Done

**Acceptance criteria**
- Given the avatar editor, when a style is chosen, it appears in the dashboard
  header, sidebar and profile immediately and persists per workspace.
- Given an invalid name, inline validation rejects it.

**Traceability:** `features/profile/`, `avatar_editor_dialog.dart`,
`avatar_store.dart`, `test/features/profile/`.

**Known boundary:** avatar is workspace-local, not synced through the account API.

### NP-15 — Display task progress summaries
**As** Alex, **I want** charts of my progress and completion trends, **so that**
I can see momentum and where marks are lost.

- Priority: Should · Points: 3 · Status: Done

**Acceptance criteria**
- Given tasks with mixed statuses, the Reports page renders progress, priority
  distribution and completion charts.
- Given a group, its progress endpoint reports completion used by the group UI.

**Traceability:** `features/reports/`, `report_charts.dart`,
`test/features/reports/`, backend progress service tests.

**Known boundary:** personal progress is derived client-side; backend progress
is group-scoped only.

### AUX-7 — Reports and exportable snapshots *(untracked capability)*
**As** Alex, **I want** a weekly progress snapshot, **so that** I can review
study patterns before a deadline.

- Priority: Could · Points: 3 · Status: Done

**Acceptance criteria**
- Given task history, the report snapshot aggregates completions, XP and streaks.
- Given an empty workspace, the page shows guidance rather than blank charts.

**Traceability:** `features/reports/`, `build_report_snapshot.dart`,
`test/features/reports/`.

---

## Epic NP-4 — Reminders, sync and distribution

### NP-14 — Implement task reminders
**As** Alex, **I want** to attach reminders to tasks and be nudged in-app,
**so that** deadlines stop sneaking up on me even when offline.

- Priority: Must · Points: 3 · Status: Done (in-app only)

**Acceptance criteria**
- Given a task with a reminder, when the time arrives, a MaterialBanner is
  shown (once per scheduled time) with Snooze 10 min / Mark done / Dismiss.
- Given a completed task, its reminder never fires.
- Given the Reminders hub, overdue reminders are grouped first, with actions to
  complete, snooze 10 minutes or clear the reminder.
- Given no reminders, an empty state explains how reminders appear.

**Traceability:** `features/reminders/` (`reminder_host.dart`,
`screens/reminders_screen.dart`), `task_store.snoozeReminder/clearReminder`,
`test/features/reminders/`.

> Improvement landed 15 November 2026: the previously stubbed "Add reminder"
> flow now schedules a stand-alone reminder task or attaches a reminder to an
> existing task, with inline date/time validation, and the orphaned backend
> reminder client was removed in favour of the offline-first task model.

**Known boundary:** no OS-level notifications or scheduling; reminders fire
only while the app is running.

### NP-26 — Build offline change queue
**As** Alex, **I want** my offline edits queued durably and replayed, **so
that** working without Wi-Fi never loses data.

- Priority: Must · Points: 8 · Status: Done

**Acceptance criteria**
- Given edits made offline, they are queued with base timestamps and replay in
  order on reconnect.
- Given a permanent rejection (4xx), the operation dead-letters after 3
  attempts without blocking unrelated queued work; dead-lettered operations can
  be discarded from the Sync centre.
- Given a corrupt queue record, the rest of the queue still replays.

**Traceability:** `features/sync/data/sync_queue_store.dart`,
`sync_service.dart`, `test/features/sync/`.

**Known boundary:** shared preferences is not encrypted at rest; the queue is
per-owner and device-local.

### NP-27 — Implement background synchronization handler
**As** Alex, **I want** sync to trigger automatically on launch, resume and
reconnect, **so that** I rarely need to press Sync.

- Priority: Should · Points: 5 · Status: Done (app-lifecycle only)

**Acceptance criteria**
- Given the app is launched/resumed/reconnects, a sync cycle is triggered
  (launch, resume, connectivity regained, periodic in-app timer).
- Given the app process is suspended, no OS-level background work runs (documented
  limitation).

**Traceability:** `features/sync/data/background_sync_handler.dart`,
`test/features/sync/`.

### NP-47 — Display synchronization status
**As** Alex, **I want** a visible sync status and a details centre, **so that**
I know what is pending, synced or blocked.

- Priority: Should · Points: 3 · Status: Done

**Acceptance criteria**
- Given pending changes, an app-wide banner shows the count; fully synced hides it.
- Given the Sync centre, last successful sync, pending operations, conflicts
  and retry are listed.

**Traceability:** `sync_status_banner.dart`, `sync_center_dialog.dart`,
`test/features/sync/`.

### NP-48 — Retry failed synchronization
**As** Alex, **I want** failed changes retried with backoff, **so that** a
flaky connection heals itself.

- Priority: Should · Points: 3 · Status: Done

**Acceptance criteria**
- Given a transient failure, the operation retries with exponential backoff.
- Given manual Retry, the queue is attempted immediately.
- Given repeated 4xx/409 failures, the operation dead-letters after 3 attempts
  and can be discarded.

**Traceability:** `sync_service.dart`, `test/features/sync/sync_service_test.dart`.

### NP-49 — Handle synchronization conflicts
**As** Alex, **I want** to resolve conflicting edits explicitly, **so that**
neither device silently destroys the other's work.

- Priority: Should · Points: 5 · Status: Done

**Acceptance criteria**
- Given a create/update/delete collision (including 404-on-update), a conflict
  record is persisted and shown in the Sync centre.
- Given the conflict UI, "Keep mine" and "Use server" are the only resolutions;
  delete-vs-update collisions are detected.
- Given resolution, both replicas converge on the surviving version.

**Traceability:** `sync_service.dart`, `sync_conflict.dart`,
`sync_service_test.dart`, `test/features/sync/`.

**Known boundary:** whole-task resolution, not field-level merge; no
three-way merge UI.

---

## Epic NP-17 — AI personal assistant

### NP-19 — Interact with AI assistant through text
**As** Alex, **I want** to ask the assistant questions and get study help,
**so that** I can unblock without leaving the app.

- Priority: Should · Points: 5 · Status: Done (mock provider default)

**Acceptance criteria**
- Given the assistant tab, messages are sent to a protected, rate-limited
  endpoint; history is kept in-session (not persisted).
- Given the default mock provider, replies are clearly labelled as mock.
- Given an OpenAI-compatible provider configured, timeouts map to safe errors;
  no provider internals or secrets appear in logs (audit redaction).

**Traceability:** `features/assistant/`, backend `modules/ai/`,
`tests/ai/ai-guardrails.test.ts`.

**Known boundary:** live provider never exercised here; mock default in Render.

### NP-46 — Convert natural-language requests into tasks
**As** Alex, **I want** to type "Submit lab report Friday at 5pm #ST0529" and
get a drafted task, **so that** capture is faster than any form.

- Priority: Should · Points: 5 · Status: Done

**Acceptance criteria**
- Given a quick-add line, the parser extracts title, date, time-of-day
  (`at 5pm`, `18:30`, noon/midnight) and `#tags` deterministically.
- Given a request for a task change through the assistant, the assistant only
  creates/updates/deletes **after explicit confirmation**, and ambiguous
  targets trigger a clarifying question instead of a guess.

**Traceability:** `task_management/domain/usecases/parse_quick_add.dart`,
`build_task_breakdown.dart`, assistant action cards, `test/features/task_management/`.

**Known boundary:** prefix/parser intent detection only; no general NLU, no
multi-intent or locale support.

---

## Group workspaces

### NP-45a — Create and manage groups
**As** Priya, **I want** to create a group and manage its members, **so that**
our shared assessment plan has a home.

- Priority: Should · Points: 8 · Status: Done

**Acceptance criteria**
- Given an authenticated owner, when a group is created, then the owner is
  recorded transactionally as the first member.
- Given a group, the owner can archive/delete it; non-owners cannot.
- Given the client, the groups page renders for signed-in sessions and shows a
  sign-in prompt for guests.

**Traceability:** backend `modules/groups/core`,
`frontend/features/groups/`, `groups_page_test.dart`, service unit tests.

**Known boundary:** backend group controller/integration paths are excluded
from the coverage gate until tests are added; no group audit events are shown
in the UI.

### NP-44 — Invite members to groups
**As** Priya, **I want** to invite classmates by email with a secure link,
**so that** only the intended people join.

- Priority: Should · Points: 5 · Status: Done

**Acceptance criteria**
- Given an invitation, the token is 32 random bytes, stored as a SHA-256 hash,
  expires after 7 days, and is bound to the invitee's email.
- Given an already-accepted or expired invite, reuse is rejected.
- Given no SMTP configured, delivery falls back to a manual one-time code
  shown to the owner.

**Traceability:** backend `modules/groups/invitation`,
`invitation_service_test`, `frontend/features/groups/group_dialogs.dart`.

**Known boundary:** not exercised against a live SMTP server in this workspace.

### NP-45b — Assign tasks to group members
**As** Priya, **I want** to assign group tasks to specific members, **so that**
everyone knows what they own.

- Priority: Should · Points: 3 · Status: Done

**Acceptance criteria**
- Given a non-member assignee, the server rejects with `ASSIGNEE_NOT_IN_GROUP`.
- Given a task not in a group context, the server rejects with `ASSIGNEE_REQUIRES_GROUP`.
- Given the assignment UI, a warning is shown before assigning outside the
  member's group.

**Traceability:** backend `task.service.ts`, `groups` module,
`test` backend service tests; frontend assignment dialog in groups pages.

**Known boundary:** no assignee notifications; assignment UI is group-context only.

---

## Quality, release and operations

### NP-16 — Test critical workflows and prepare release
**As** Sam (and stakeholders), **I want** critical workflows tested and a
tagged release with provenance, **so that** we can ship with confidence.

- Priority: Must · Points: 8 · Status: Partial — release never executed; no
  `v*.*.*` tag cut from this workspace

**Acceptance criteria**
- Given a `v*.*.*` tag, the release workflow re-verifies versions, reruns all
  gates, packages the web build, attests provenance and publishes the release.
- Given a deployment, the read-only smoke test checks health, auth and 404s.
- Given a release, manual NFR gates (screen reader, 200% scale device test,
  HTTPS/CORS, DB backup, rollback rehearsal) are evidenced.

**Traceability:** `.github/workflows/release.yml`, `scripts/smoke-test.mjs`,
`docs/release/RELEASE_CHECKLIST.md`, `docs/compliance/NFR_RELEASE_GATES.md`,
`test/` suites, `e2e/`.

## Epics NP-1…NP-5, NP-17 — Roll-up status

All child stories of NP-1…NP-5 and NP-17 are delivered except NP-16, which
carries the open release gates above. Epics close when NP-16 closes.

---

## Backlog — catalogued gaps (NOT implemented)

Each entry follows the same format and is ready to pull into a sprint. Points
are estimates, not commitments.

### BACKLOG-1 — OS-level reminder notifications
**As** Alex, **I want** reminders even when the app is closed, **so that** I
never miss a deadline.
- Priority: Should · Points: 8 · Needs platform notification spike + permission UX.

**Acceptance criteria:** OS notification scheduled per task reminder; fires with
the app closed; deep-links into the task; graceful denial path.

### BACKLOG-2 — AI Rubric-to-Roadmap workflow (Phase 4)
**As** Alex, **I want** to paste my rubric and get a proposed milestone plan I
can edit, **so that** I start on a large assessment with a realistic schedule.
- Priority: Could · Points: 13 · Backend CRUD scaffolding exists (`/api/rubrics`,
  `/api/roadmaps`); AI generation, review UI and approval flow missing.

**Acceptance criteria:** paste rubric → structured criteria/weights extracted →
milestone draft with estimates scheduled backwards from the due date → side-by-side
review; accept/edit/reject per item; provenance and "AI-assisted" labels; no item
committed without explicit student approval.

### BACKLOG-3 — Field-level (three-way) sync merge
**As** Alex, **I want** non-conflicting fields merged automatically, **so that**
only genuinely diverging edits need my decision.
- Priority: Should · Points: 8.

**Acceptance criteria:** server merges disjoint field changes; UI shows a
three-way diff for true conflicts; no silent overwrite of explicit user choice.

### BACKLOG-4 — Tag management (rename, merge, colour)
**As** Alex, **I want** to rename and merge tags, **so that** `#ST0529` and
`#st0529` converge.
- Priority: Could · Points: 5.

**Acceptance criteria:** global tag rename/merge with case-insensitive matching;
colour chips per tag; per-task tag icons remain consistent with filters.

### BACKLOG-5 — Account deletion in app
**As** Alex, **I want** to delete my account and data, **so that** the app
honours my right to erasure.
- Priority: Should · Points: 5 · Backend admin disable exists; self-service missing.

**Acceptance criteria:** user-initiated deletion with password confirmation;
account disabled or hard-deleted per retention policy; confirmation email;
shared-data (groups) handled gracefully.

### BACKLOG-6 — Assignee notifications
**As** Priya, **I want** members notified when assigned, **so that** work does
not sit unread.
- Priority: Could · Points: 5.

**Acceptance criteria:** in-app notification plus (optional) email; unassigned
when the assignee leaves; respects a per-user notification preference.

### BACKLOG-7 — MFA enrolment UI
**As** Alex, **I want** to enable TOTP in the app, **so that** I do not need
API calls to protect my account.
- Priority: Could · Points: 5 · Backend already supports MFA.

**Acceptance criteria:** QR enrolment flow; recovery codes; disable with
password confirmation.

### BACKLOG-8 — Group coverage gate and controller/integration tests
**As** the developer, **I want** `modules/groups` (and `audit`) un-excluded from
the coverage ratchet, **so that** quality gates cover shared workspaces.
- Priority: Should · Points: 5 · Raises the backend baseline; do not lower the ratchet.

**Acceptance criteria:** controller and integration tests lift groups above the
exclusion threshold; ratchet raised, never lowered.

### BACKLOG-9 — Full-journey E2E (signup → task CRUD → offline → sync)
**As** Sam, **I want** one end-to-end journey across a fresh account, **so
that** release candidates are proven against the real stack.
- Priority: Must · Points: 8 · Called out as residual risk in the CI/CD report.

**Acceptance criteria:** Playwright suite covers signup, task CRUD, offline
edit, reconnect, conflict resolution; runs in CI against the compose stack.

### BACKLOG-10 — Refresh-token rotation and server-side session store
**As** Sam, **I want** refresh tokens rotated and server-side revocable, **so
that** a stolen refresh token ages out quickly.
- Priority: Should · Points: 8 · Listed under hardening in ENTERPRISE_AUTH.md.

**Acceptance criteria:** rotation on every refresh; family-based reuse detection;
logout revokes server-side; optional Redis-backed store.

### BACKLOG-11 — Group roles Editor and Viewer, comments, activity feed
**As** Priya, **I want** finer roles and an activity trail, **so that**
supervisors can watch read-only and members comment on tasks.
- Priority: Could · Points: 8.

**Acceptance criteria:** Editor/Viewer roles enforced server-side; per-task
comments; owner-visible audit/activity feed from `modules/audit`.

### BACKLOG-12 — Export/import of task data
**As** Alex, **I want** a JSON export of my tasks, **so that** I keep a backup
outside the app.
- Priority: Could · Points: 3.

**Acceptance criteria:** versioned JSON export; lossless import; no network
required.

---

## Traceability summary

| Story(ies) | Status | Primary implementation | Primary tests |
|------------|--------|----------------------|---------------|
| NP-6, NP-18 | Done | Repo, CI, Jenkins, Docker, render.yaml | CI, release workflow |
| NP-7, NP-50 | Done | `app_shell.dart`, `app_router.dart` | `test/core/`, navigation tests |
| AUX-1 | Done | `features/onboarding/` | onboarding tests |
| AUX-2 | Done | `api_client.dart`, `features/authentication/` | backend auth integration, frontend auth tests |
| AUX-3 | Done | `forgot/reset` screens, backend reset | backend auth tests |
| NP-8 – NP-10, NP-29 | Done | `features/home/` | `test/services/`, `test/screens/` |
| NP-11, NP-13, NP-12, NP-15 | Done | dashboard, badges, avatar, reports | `test/screens/`, `test/features/reports/` |
| NP-14 | Done (in-app) | `features/reminders/` | `test/features/reminders/` |
| NP-26, NP-27, NP-47–49 | Done | `features/sync/` | `test/features/sync/` |
| NP-19, NP-46 | Done | assistant, quick-add parser | `test/features/assistant/`, `task_management/`, AI guardrails |
| NP-45a/b, NP-44 | Done | `modules/groups/`, `features/groups/` | backend group service tests, `groups_page_test.dart` |
| NP-16 | Partial | release pipeline | see NP-16 section |
| AUX-4 | Partial | backend MFA | backend auth tests |
| BACKLOG-1…12 | Not built | — | — |

For the narrative evidence trail (CI runs, coverage ratchets, release gates),
see `docs/reports/USER_STORY_CICD_REPORT.md` and
`docs/reports/RUBRIC_SELF_ASSESSMENT.md`.
