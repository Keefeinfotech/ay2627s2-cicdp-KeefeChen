# Round 5 – Design DNA (from the six references)

Distilled, reusable principles and how each is adapted for Auxilia. No reference is copied literally; layouts are re-composed around Auxilia's students-and-deadlines context.

## D1. One hero metric, then supporting stats (Todoist)
- **Reference behaviour:** Daily/Weekly segmented control; ring for goal; streak line; 7-day bar list.
- **Auxilia adaptation:** Insights screen leads with a completion ring (done/total this week), then streak, then a 7-day bar list. Dashboard keeps a single goal ring in the productivity summary card.
- **Rule:** Never more than one hero visualization per screen.

## D2. Non-modal assistant with suggested actions (Notion AI)
- **Reference behaviour:** Docked panel, greeting, 4 suggestions, single input, source picker.
- **Auxilia adaptation:** Desktop: 400px docked panel on the right, closable, page stays interactive. Mobile: full-screen sheet. Suggested prompts: "What's due today?", "Remind me about X tomorrow", "Plan my study week". NL create flow always ends in an **editable preview card** with Confirm / Edit / Cancel — never silent creation.
- **Rule:** The assistant may propose; only the user confirms.

## D3. Momentum framing over widget grids (Brilliant)
- **Reference behaviour:** Greeting, streak card, resume CTA, recommendations.
- **Auxilia adaptation:** Dashboard header: "Good afternoon, Keefe" + level chip + streak. First content block: "Pick up where you left off" card naming the single next deadline. Gamification stays in the header (XP + streak), never as standalone dashboard modules.
- **Rule:** Every screen answers "what should I do next?" within one glance.

## D4. Group tasks by when-to-do (Asana)
- **Reference behaviour:** Sections by horizon; column headers; bottom tabs on mobile.
- **Auxilia adaptation:** Task views group as Overdue / Due today / This week / Later, with course-tag filter chips (e.g. COMP1511) above the list. Mobile bottom bar: Home / Tasks / Assistant / Insights / Profile.
- **Rule:** Time horizons outrank project folders for daily execution.

## D5. One decision per dialog, one primary action (Linear)
- **Reference behaviour:** Helper text + calendar + single "Save due date".
- **Auxilia adaptation:** All dialogs: max one primary button; destructive actions are separate and red; helper text explains consequence; Cancel always top-right or left of primary.
- **Rule:** If a dialog needs two sentences to explain, simplify the dialog.

## D6. Progress as a sentence + next action (Coursera)
- **Reference behaviour:** "12% of Module completed" + progress bar + "Up Next — 15 min".
- **Auxilia adaptation:** Deadline detail and Home "Continue" card read like a sentence ("3 of 5 done — 2 due Friday") with a single CTA ("Start next task"). Course tags render as filter chips everywhere.
- **Rule:** Numbers need a verb; CTAs need one job.

## D7. Empty/error states with a path forward (Todoist, Cron)
- **Reference behaviour:** Illustration/icon + one line + one action; inline error text with retry.
- **Auxilia adaptation:** Every list has an empty state (icon + sentence + primary action); every error has a message + Retry; forms validate inline on blur with the error under the field.

## D8. Restrained navigation (Asana + Brilliant)
- **Reference behaviour:** 5-item bottom bar (mobile), 3–5 item top nav with search (web).
- **Auxilia adaptation:** Mobile: 5-tab bottom bar. Web: collapsible 256px sidebar (Direction A), minimal top bar + whitespace (B), icon rail + panels (C). Search always ⌘K on web.

## Layout grid and tokens shared by all directions
- 8px spacing grid; 4/8/12/16/24/32/48 steps.
- Radius: 8 (inputs/small), 12 (cards), 16 (sheets/modals), 999 (chips/avatars).
- Type: Roboto; scale 12/14/16/20/24/32/40; weights 400/500/600/700.
- Contrast: body text ≥ 7:1 on light surfaces; ≥ 4.5:1 for secondary; focus ring 2px Trust Blue with 2px offset.
- Motion: 120–200ms ease-out for micro, 240–320ms for sheets; `prefers-reduced-motion: reduce` disables all non-essential motion.
- Icons: Lucide-style stroke icons (inline SVG), 20px default, 1.5px stroke.

## Anti-patterns explicitly rejected
1. Purple or purplish gradients (brand rule).
2. Emoji in UI copy (brand rule).
3. More than one hero visualization per screen.
4. Two competing primary buttons in one view.
5. Silent AI task creation without preview/confirm.
6. Copying competitor brand colours wholesale (Todoist red, Coursera blue, Asana coral as accent).
7. Gamification badges as dashboard content modules.
8. Modal-first interactions for trivial choices.
