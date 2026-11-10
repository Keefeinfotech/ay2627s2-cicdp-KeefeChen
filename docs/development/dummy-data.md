# Dummy Data Generation

Auxilia includes a seed script that populates the MongoDB database with
realistic dummy data for development, testing, and UI review.

## Scripts

| Script | Description |
|--------|-------------|
| `npm run seed` | Seed data (skips records that already exist) |
| `npm run seed:reset` | Clear all collections, then seed fresh |
| `npm run seed:dry-run` | Show current record counts without writing |

Run from the `backend/` directory:

```bash
cd backend
npm run seed          # seed without duplicating
npm run seed:reset    # wipe and re-seed
```

## What is seeded

| Collection | Count | Notes |
|------------|-------|-------|
| Users | 5 | 1 admin + 4 regular (1 pending verification) |
| Groups | 3 | With memberships and roles |
| Memberships | 8 | Group-user links with OWNER/ADMIN/MEMBER roles |
| Tasks | 22 | Covers all test scenarios (see below) |
| Roadmaps | 2 | With nested items and varied statuses |
| Rubrics | 1 | With weighted criteria |
| Feedback | 4 | Bug report, feature request, praise, UI feedback |
| Calendar Events | 6 | Past, today, upcoming, cancelled, all-day |
| Study Sessions | 2 | Scheduled group sessions |

## Test scenarios covered

### Tasks

- Pending (todo), in-progress, completed, archived
- Overdue, due today, due within 7 days, no deadline
- High, medium, low, urgent priority
- With and without course, tags, group assignment, assignee
- Soft-deleted records (deletedAt set)

### Groups & Collaboration

- Private and public visibility
- OWNER, ADMIN, MEMBER roles
- Active and pending membership statuses
- Shared tasks across groups

### Calendar & Scheduling

- Past events (completed)
- Today's events
- Upcoming events
- All-day events
- Overlapping schedules
- Events with and without group association

### Progress & Productivity

- Different task completion rates per user
- Roadmaps in draft and approved status
- Roadmap items in pending, in-progress, and done states
- Study sessions scheduled in the future

## Reset mechanism

`npm run seed:reset` drops all documents from every collection before
re-seeding. This is safe for development databases only — never run against
production.

## Credentials

Seed user accounts use the following passwords (all meet the 12-character
minimum with uppercase, lowercase, number, and special character):

| Email | Password | Role |
|-------|----------|------|
| admin@auxilia.test | Admin$ecure2026 | admin |
| alice@example.com | Alice$ecure2026 | user |
| bob@example.com | Bob$ecure2026 | user |
| carol@example.com | Carol$ecure2026 | user |
| david@example.com | David$ecure2026 | user |

These accounts are intended for development only and should never be used in
production.

## Repeatable seeding

The script uses an upsert pattern keyed on:

- **Users**: `email` (unique)
- **Groups**: `groupId` (unique)
- **Memberships**: `groupId + userId` (compound unique index)
- **Tasks / Roadmaps / Rubrics / Study Sessions**: `_id` (UUID primary key)
- **Feedback**: `userId + title`
- **Calendar Events**: `userId + title + startTime`

Running `npm run seed` multiple times will not create duplicates. Existing
records are left unchanged.

## Database compatibility

The seed script targets MongoDB via Mongoose (the backend's primary store).
The frontend uses Drift/SQLite for local offline-first persistence and does
not share seed data with the backend. To populate the local Drift database,
use the frontend's sync service after authenticating with a seeded backend
account.
