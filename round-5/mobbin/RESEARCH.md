# Round 5 – Mobbin Research (Auxilia)

**Product:** Auxilia – Personal Secretary & Task Automation Assistant
**Slogan:** "Help Anywhere, Learn Together."
**Audience:** Students managing academic responsibilities, internships and personal commitments.
**Date:** 2026-11-19

## Method and honesty note

The brief asked for the Mobbin MCP. **No Mobbin MCP server is connected to this environment** (verified via the OpenCode MCP resource listing and a tool-catalog search for "mobbin", both empty). As a substitute, research was performed against mobbin.com using web search and direct page fetches. All six reference screens were downloaded as high-resolution images from Mobbin's public CDN into `round-5/mobbin/`. Every reference below links to its Mobbin source page. Where a query returned only collections, the closest individual screen pages were used instead. Nothing in this document is invented; screen behaviour is described from the actual downloaded images.

## Queries executed (10)

| # | Query topic | Result highlights | Source |
|---|-------------|-------------------|--------|
| 1 | Student productivity dashboards | Brilliant Web Dashboard (progress + streak), Coursera iOS Course Dashboard, Udemy/Uxcel/Babbel patterns | https://mobbin.com/explore/web/screens/student-performance-dashboard |
| 2 | Task management and task creation | Asana Android Categorized Task List (Recently assigned / Do today / Do next week / Do later), Linear due-date flows, Trello calendar power-up | https://mobbin.com/explore/mobile/screens/task-list (via search) |
| 3 | Calendar and deadline management | Linear Web Due Date Picker (modal calendar, "Save due date"), Microsoft Teams iOS Task Due Date Selection | https://mobbin.com/explore/screens/bd45deef-178c-499c-9233-4d8c232eb6ed |
| 4 | AI assistant conversational interfaces | Notion Web AI Chatbox, ChatGPT iOS, Copilot Android, Claude suggested tasks | https://mobbin.com/explore/screens/1ab7a283-567f-442a-83e9-092fae203fcc |
| 5 | Natural-language task creation | Notion AI chatbox with suggested actions, Copilot suggested prompts | https://mobbin.com/explore/screens/7beeff80-b4d2-440f-a1ec-8d146d1d9b80 |
| 6 | Reminder and notification management | Todoist empty states for comments/search, Reminders app empty state, Cron Calendar toast error | https://mobbin.com/explore/mobile/screens/empty-state |
| 7 | Productivity analytics and progress summaries | Todoist iOS Productivity Summary (daily goal ring, weekly segmented control, 7-day bar list), Uxcel learning statistics | https://mobbin.com/explore/screens/a7097612-d8bc-43ad-b7ac-a33f7e7ac4d9 |
| 8 | Onboarding and account management | Todoist onboarding flow (signup + loading), Brilliant streak home, no excessive steps | https://mobbin.com/explore/web/flows/onboarding |
| 9 | Mobile navigation and responsive layouts | Asana bottom tab bar (Home / My Tasks / Inbox / Search / Account), Brilliant top nav, Coursera segmented module pills | https://mobbin.com/explore/screens/89e62b13-562c-4b76-9b02-a59f8879a973 |
| 10 | Empty states, loading states and error handling | Todoist empty states (search, comments), Cron Calendar error toast, Chipotle inline errors | https://mobbin.com/explore/mobile/screens/error |

## Selected references (6)

### 1. Todoist – iOS Productivity Summary
- **File:** `todoist-productivity-summary.png`
- **Source:** https://mobbin.com/explore/screens/a7097612-d8bc-43ad-b7ac-a33f7e7ac4d9
- **Screen/interaction:** Productivity sheet: Daily / Weekly / Karma segmented control; daily goal ring (3/5 tasks); streak block; "Completed in the last 7 days" horizontal bar list.
- **Relevant principle:** Progressive disclosure of stats behind a segmented control; one hero metric (goal ring) + supporting streak + trend list.
- **What Auxilia can learn:** Mirror the Daily/Weekly tabs for insights; use a completion ring for the daily goal; show streak flame as a single number, not a wall of stats.
- **What not to copy:** Red accent for goals and "Done" (conflicts with Auxilia Trust Blue); Karma gamification that is irrelevant to students; tiny unlabeled chart bars.

### 2. Notion – Web AI Chatbox
- **File:** `notion-ai-chatbox.png`
- **Source:** https://mobbin.com/explore/screens/1ab7a283-567f-442a-83e9-092fae203fcc
- **Screen/interaction:** Floating AI panel bottom-right; greeting "How can I help you today?"; 4 suggested actions; single-line input with source picker; non-modal (page remains interactive).
- **Relevant principle:** Assistant as a dockable, non-blocking panel with suggested prompts, not a full-screen detour.
- **What Auxilia can learn:** Assistant panel docked right on desktop, full-screen on mobile; suggested actions ("Add a task…", "What's due today?"); confirm-before-create preview card for NL-created tasks.
- **What not to copy:** Emoji in prompts; the Sparkle-branded "AI" treatment; unbounded sources picker Auxilia doesn't have.

### 3. Brilliant – Web Dashboard
- **File:** `brilliant-web-dashboard.png`
- **Source:** https://mobbin.com/explore/screens/023b19e2-1a8c-471d-9858-d2330426bb7f
- **Screen/interaction:** Home = "Welcome" + streak card, "Jump back in" resume card with one strong CTA, "Recommended for you" grid; top nav with search.
- **Relevant principle:** Personal momentum framing (streak + resume) as the hero, not a widget grid.
- **What Auxilia can learn:** Greeting + single resume CTA ("Pick up where you left off") for a student's next deadline; XP/level chip in header.
- **What not to copy:** Yellow streak as primary brand; illustration-heavy course cards; gamification overload for a productivity tool.

### 4. Asana – Android Categorized Task List
- **File:** `asana-categorized-task-list.png`
- **Source:** https://mobbin.com/explore/screens/89e62b13-562c-4b76-9b02-a59f8879a973
- **Screen/interaction:** Task list grouped by action horizon (Recently assigned / Do today / Do next week / Do later); column headers (TASK NAME / DUE DATE); bottom tab bar; FAB.
- **Relevant principle:** Grouping by when-to-do beats grouping by project for daily execution.
- **What Auxilia can learn:** Dashboard groups tasks as "Due today / Overdue / This week / Later"; sticky section headers; FAB for quick add on mobile.
- **What not to copy:** Red FAB (destructive connotation); empty sections rendered as dead headers; cramped 12px column labels.

### 5. Linear – Web Due Date Picker
- **File:** `linear-due-date-picker.png`
- **Source:** https://mobbin.com/explore/screens/bd45deef-178c-499c-9233-4d8c232eb6ed
- **Screen/interaction:** Modal date picker with dual-month calendar, explicit helper text ("Issue needs to be completed by this date"), full-width primary "Save due date".
- **Relevant principle:** One decision per modal; helper text explains consequence; single clear commit action.
- **What Auxilia can learn:** Task editor deadline control = helper text + calendar + one primary action; never two competing primaries in a dialog.
- **What not to copy:** Purple CTA; scrimodality for a trivial choice (inline popover is fine); tiny dimmed placeholder states.

### 6. Coursera – iOS Course Dashboard
- **File:** `coursera-ios-course-dashboard.png`
- **Source:** https://mobbin.com/explore/screens/d76cce29-fa86-4e42-a549-54d3765ad5d9
- **Screen/interaction:** Course context header + tab strip (Dashboard/Grades/Forums…); module progress pills; "12% complete" progress bar; "Up Next" card with primary "Up Next — 15 min" button.
- **Relevant principle:** Context header + segmented tabs; progress as a sentence ("12% of Module completed"), next action as a single prominent card.
- **What Auxilia can learn:** Deadline detail view with progress sentence + one "Up next" action; module-style course tags (COMP1511 style) as filter chips.
- **What not to copy:** Download/sync UI Auxilia doesn't have; infinitely scrolling tab strip; bright blue "Up Next" pill on bordered card (two competing emphases).

## Verdicts carried into the design DNA
See `DNA.md`.
