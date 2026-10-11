# Goal Spec — Winter Arc iOS App

> Purpose: define *what* we are building and *why*, independent of how it is built.
> Builds on `winter-arc-concept-spec.md`. Requirement IDs (FR-x, NFR-x) are referenced by `frontend-spec.md` and later specs.

## 1. Product Summary
- **One-liner:** A focused, offline-first iOS habit tracker built specifically for running a 90-day Winter Arc — pick your pillars, lock in your non-negotiables, check in daily, and finish the year ahead.
- **Problem statement:** General-purpose habit apps are built for open-ended, forever habits. A Winter Arc is the opposite: a hard start, a hard end, a countdown, a small set of non-negotiables grouped into pillars, and a ruleset that defines what a miss costs. People currently improvise this with notes apps, spreadsheets, or bloated trackers that add friction — and friction is the number one reason they stop logging by week 3.
- **Vision:** The default app people reach for every autumn when they decide to "lock in". Start with a single-arc, single-user tracker; grow into arc templates, multi-arc history, and light accountability features once the core loop is proven.

## 2. Target Users
| Persona | Description | Primary need |
|---|---|---|
| **First-timer** | Saw Winter Arc on TikTok/YouTube, motivated, has never completed a 90-day challenge. Likely to over-commit. | Guided setup that keeps the habit list small, and a daily check-in that takes seconds. |
| **Repeat participant** | Has done one or more arcs (or 75 Hard). Knows what they want; hates onboarding friction and clutter. | Fast setup, clear streak and Consistency Score read-outs, a proper end-of-arc review. |
| **Mid-arc rescuer** | Starts the app late (e.g. Day 10) or is already slipping in the Dip. | Ability to backfill days, forgiving ruleset options, and encouragement rather than shame. |

## 3. Goals
### 3.1 Primary goals (must achieve)
- [ ] G1 — A user can set up a complete Winter Arc (dates, pillars, habits, ruleset) in under 3 minutes.
- [ ] G2 — A user can complete their daily check-in in under 30 seconds with one tap per habit and no confirmation step; for the recommended three-habit setup that is three taps for a fully "done" day.
- [ ] G3 — The app always shows where the user stands: day X of N, days remaining, per-habit streaks, and the Consistency Score.
- [ ] G4 — The app works fully offline with no account required; data lives on-device.
- [ ] G5 — A user who finishes the arc gets a clear end-of-arc summary they can look back on.

### 3.2 Secondary goals (nice to have)
- [ ] S1 — Home-screen widget showing day count and today's check-in state.
- [ ] S2 — Before/after photo capture at arc start and end.
- [ ] S3 — Weekly review prompt with a short reflection note.
- [ ] S4 — Arc templates (e.g. "Classic Oct–Dec", "Fitness-focused", "Digital Detox") to speed up setup.

### 3.3 Non-goals (explicitly out of scope for v1)
- Social features **inside the app**: feeds, friends, leaderboards, comparison with other users. These need accounts, a backend and moderation, and would break the app's three load-bearing claims at once.
  - *Amended 3 Oct 2026:* "sharing progress cards" left this bullet and became FR-32. It was swept up with its neighbours, but it shares none of their machinery — a rendered image handed to the system share sheet needs no account, no backend and no networking code (`CONV-02` passes unchanged, because the system does the sending outside the app's process).
- Accounts, cloud sync, or multi-device support.
- Android or web versions.
- Monetisation (subscriptions, IAP).
- HealthKit / Screen Time API integrations for automatic habit completion.
- Open-ended habits with no arc — every habit belongs to an arc.
- Running more than one arc simultaneously.

## 4. Core User Journeys

### UJ1 — Set up an arc
1. User opens the app for the first time and sees a short explanation of what a Winter Arc is.
2. User picks a start and end date (defaults to Oct 1 – Dec 31 of the current year, or today if already inside that window).
3. User selects 3–5 pillars from a preset list (Physical Health, Mental Resilience, Career & Finances, Digital Detox, Custom).
4. Under each pillar, user adds 1–3 daily habits from suggestions or by typing their own. The app warns if the total exceeds 7.
5. User chooses a ruleset (Streaks, the default; Consistency Score with a target; Grace Days with a grace-day budget).
6. Optionally writes a one-line "why" statement and sets a daily reminder time.
7. User taps **Start Arc** and lands on the Today screen — at Day 1, or on the countdown state if the chosen start date is still in the future.

### UJ2 — Daily check-in
1. User opens the app (or taps the reminder notification) and lands on Today.
2. Today shows the day counter, days remaining, and the habit list grouped by pillar, each with a done/not-done toggle.
3. User marks habits done as they complete them; a fully completed day is celebrated with subtle feedback.
4. At midnight the day rolls over; any unmarked habit is recorded as a miss according to the ruleset.

### UJ3 — Review progress
1. User opens the Progress tab.
2. Sees the Consistency Score, per-habit current and best streaks, per-pillar completion, and a calendar heat-map of the arc so far.
3. Can tap any past day to see or edit what was logged (within an edit window defined by NFR-6).

### UJ4 — Handle a miss
1. A day passes with one or more habits unmarked.
2. **Streaks:** that habit's streak resets to 0; the arc continues.
3. **Consistency Score:** the score drops; nothing else changes.
4. **Grace Days:** a grace day is used; the app shows grace days remaining. A budget of N forgives N missed days; the first missed day *after* the budget is used up marks the arc failed. The arc remains viewable and the user chooses to restart (UJ7) or keep going (FR-31).
5. In all cases the app shows an encouraging, non-punitive message on the next open.

### UJ5 — Finish an arc
1. On the final day the user completes their last check-in.
2. The app presents an end-of-arc summary: Consistency Score, best streaks, habits checked off, pillar breakdown, and the "why" statement they wrote at the start.
3. User can add a closing reflection note.
4. The arc is archived; the user is offered "Start a new arc" (UJ7, pre-filled from this arc) or "Done for now".

### UJ6 — Join late or backfill
1. User sets up an arc with a start date in the past.
2. The app asks whether to mark the elapsed days as done, missed, or leave them for manual backfill.
3. User can backfill any past day from the Progress calendar.

### UJ7 — Restart an arc
1. User chooses **Restart** from the active arc's settings, from the Grace Days failure screen (UJ4), or from the end-of-arc summary (UJ5).
2. The app explains that the current arc will be archived (kept, read-only) and a new one started from today.
3. User confirms and enters the setup flow, pre-filled with the current arc's pillars, habits, ruleset, "why" statement, and reminder time, with an end date preserving the original length.
4. The current arc stays untouched while the user edits the draft.
5. On **Start Arc**, the previous arc is archived with a status of *abandoned*, *failed*, or *completed* as appropriate and the new one is created — in one atomic operation. Cancelling at any step leaves the previous arc exactly as it was. The user lands on Today at Day 1.

## 5. Functional Requirements
| ID | Requirement | Priority | Journey |
|---|---|---|---|
| FR-1 | Create one active arc with a start date, end date, and computed length in days | P0 | UJ1 |
| FR-2 | Default arc dates to Oct 1 – Dec 31 of the current year; allow any custom range of 30–180 days | P0 | UJ1 |
| FR-3 | Select 3–5 pillars from presets or create a custom pillar with a name and icon | P0 | UJ1 |
| FR-4 | Add 1–3 habits per pillar; each habit is a binary daily action with a name | P0 | UJ1 |
| FR-5 | Warn (not block) when total habits exceed 7 | P1 | UJ1 |
| FR-6 | Choose a ruleset: Streaks (default), Consistency Score (configurable target %), Grace Days (configurable grace-day budget) | P0 | UJ1, UJ4 |
| FR-7 | Record an optional "why" statement at setup, shown on the end-of-arc summary and on the next open after a miss | P1 | UJ1, UJ4, UJ5 |
| FR-8 | Schedule a single daily repeating local reminder at a user-chosen time with fixed content (iOS repeating notifications cannot vary per day) | P1 | UJ1, UJ2 |
| FR-9 | Today screen shows day X of N, days remaining, and today's habits grouped by pillar with done/not-done toggles | P0 | UJ2 |
| FR-10 | Toggling a habit persists immediately; no save button | P0 | UJ2 |
| FR-11 | Detect day rollover (midnight, local time zone) on app foreground and finalise the previous day's misses per ruleset | P0 | UJ2, UJ4 |
| FR-12 | Compute and display per-habit current streak and best streak | P0 | UJ3 |
| FR-13 | Compute and display the Consistency Score (completed habit-days ÷ elapsed habit-days, as a %) | P0 | UJ3 |
| FR-14 | Compute and display per-pillar completion % | P1 | UJ3 |
| FR-15 | Calendar heat-map of the arc showing each day's completion level | P1 | UJ3 |
| FR-16 | Tap a past day to view and edit its habit entries (subject to NFR-6) | P1 | UJ3, UJ6 |
| FR-17 | Grace Days: track grace days used vs. budget; mark the arc failed when exhausted while keeping data viewable; offer restart (FR-28) | P0 | UJ4, UJ7 |
| FR-18 | Show a non-punitive message on next open after a missed day | P2 | UJ4 |
| FR-19 | End-of-arc summary with Consistency Score, best streaks, total habit-days, pillar breakdown, and the "why" statement | P0 | UJ5 |
| FR-20 | Add a closing reflection note; archive the arc; offer to start a new one via restart (FR-28) | P1 | UJ5, UJ7 |
| FR-21 | View archived arcs (read-only), each labelled completed / failed / abandoned | P2 | UJ5, UJ7 |
| FR-22 | When the start date is in the past, offer to mark elapsed days as done / missed / leave for backfill | P1 | UJ6 |
| FR-23 | Edit the active arc's habits and pillars mid-arc; historical entries are preserved | P1 | UJ1 |
| FR-24 | Abandon the active arc (archive as *abandoned*, data preserved) with confirmation; delete permanently as a separate, secondary action | P1 | UJ7 |
| FR-25 | Home-screen widget: day X of N and today's done/total count | P2 | UJ2 |
| FR-26 | Before/after photo capture at arc start and end, stored locally | P2 | UJ1, UJ5 |
| FR-27 | Weekly reflection prompt with a short free-text note | P2 | UJ3 |
| FR-28 | Restart: create a new arc pre-filled with the current arc's pillars, habits, ruleset, "why", reminder time, and length, starting today, editable before confirmation; on confirmation, archive the old arc (status completed / failed / abandoned) and start the new one in a single atomic operation. Cancelling changes nothing. Single flow shared by FR-17, FR-20, and FR-24 | P1 | UJ7 |
| FR-29 | Change the ruleset (and its target / budget) mid-arc; before applying, show the resulting state computed from existing entries (e.g. grace days already used, or immediate failure) | P1 | — |
| FR-30 | Edit the "why" statement mid-arc from Settings | P2 | — |
| FR-31 | After a Grace Days failure, choose **Keep going** (arc stays failed, daily tracking continues to the end date) or **Restart** (FR-28); the choice is persisted so the failure screen is not shown again. Until a choice is made, the failure screen is presented on every open | P1 | UJ4, UJ7 |
| FR-32 | Share a progress card: a view rendered locally to an image (`ImageRenderer`) and handed to the system share sheet (`ShareLink`), so the user posts it wherever they choose. Always user-initiated. Offered on Progress and on arc completion. No upload, no account, no third party — the app never transmits it | P2 | UJ3, UJ5 |
| FR-34 | **Quick start.** One tap from the Welcome screen creates a Classic arc (Oct 1 – Dec 31) with three suggested pillars and their default habits already filled in, landing straight on Today. The full seven-step flow stays, reached by a secondary action; everything quick start chose is editable afterwards in Settings. Setup becomes opt-in for people who want to customise, instead of a toll every user pays before seeing the app work | P0 (M7) | UJ1 |
| FR-35 | **The daily reminder defaults on**, at 20:00, with notification permission requested at the moment it is switched on rather than during setup. A user who never opens Settings still gets the one thing that brings them back tomorrow. Turning it off stays one tap, and the existing §8 design is unchanged — still exactly one pending request | P0 (M7) | UJ2 |
| FR-33 | The weekly reflection card (FR-27) carries the share action from Day 7, refreshing each Monday. **This is the whole of the weekly nudge:** no new prompt, no second notification, no modal. The cadence is FR-27's, already designed and already shipping | P2 | UJ3 |

## 6. Non-Functional Requirements
| ID | Requirement |
|---|---|
| NFR-1 | **Platform:** iOS 18.0+, iPhone only (iPad runs in compatibility mode). Portrait orientation. |
| NFR-2 | **Performance:** cold launch to interactive Today screen in under 1 s on an iPhone 12 or newer; all interactions respond within 100 ms. |
| NFR-3 | **Offline:** 100 % of functionality works with no network connection. The app makes no network calls in v1. |
| NFR-4 | **Privacy & data:** all data stored on-device only. No analytics SDKs, no tracking, no account. Photos (FR-26) are stored in the app sandbox, not the user's photo library, unless the user chooses to export. Deleting the app deletes all data. |
| NFR-5 | **Data integrity:** a check-in toggle must never be lost; writes are synchronous to local persistence. Day rollover must be idempotent and correct across time-zone changes and DST transitions. |
| NFR-6 | **Edit window:** past days can be edited up to 7 days back by default (configurable in settings; "unlimited" allowed). Prevents accidental rewriting of history while allowing honest backfill. |
| NFR-7 | **Accessibility:** full VoiceOver support with meaningful labels and traits; Dynamic Type up to accessibility sizes without layout breakage; WCAG AA contrast in light and dark mode; Reduce Motion respected. |
| NFR-8 | **Localization:** English only in v1, but all user-facing strings go through the localization system from day one. Dates and numbers use the device locale. |
| NFR-9 | **Reliability:** no crashes in the core loop (setup → check-in → progress). Crash-free sessions ≥ 99.5 %. |
| NFR-10 | **Size:** app binary under 20 MB. |

## 7. Success Metrics
| Metric | Target | How measured |
|---|---|---|
| Setup completion | ≥ 80 % of users who start setup finish it | Local counters surfaced in a debug screen (no analytics in v1); TestFlight feedback |
| Time to first check-in | < 30 s from app open to first habit toggled on Day 1 | Manual timing during usability tests |
| Daily check-in rate | ≥ 70 % of arc days have at least one habit logged | Derived from local data; self-reported by testers |
| Arc completion | ≥ 40 % of users who reach Day 14 reach the final day | TestFlight cohort survey at end of arc |
| Dip survival | Check-in rate in weeks 3–6 within 15 points of weeks 1–2 | Local data from tester cohort |
| Crash-free sessions | ≥ 99.5 % | Xcode Organizer / TestFlight crash reports |
| Accessibility audit | Zero blocking VoiceOver issues on core screens | Manual audit with Accessibility Inspector |

## 8. Constraints & Assumptions
- **Constraints:**
  - Solo developer working in a spec-driven, AI-assisted workflow. Implementation **and testing** are both driven by specs: every feature traces back to an FR/NFR in this document, every screen to `frontend-spec.md`, and every test case to a `test-spec.md` that cites the requirement it verifies. No code is written for a requirement that is not in a spec.
  - Native Swift/SwiftUI only; no cross-platform frameworks.
  - **The complete app (all P0, P1, and P2 requirements) ships to the App Store this week.** Scheduling of individual milestones is managed outside this spec. The only sanctioned scope reduction is the one in §9: if M3 slips, P2 items are cut in the order listed there, and the App Store submission still happens.
  - The app must be live before the classic arc window opens on Oct 1.
  - App Store Review guidelines apply (privacy manifest, notification permission rationale, screenshots, App Privacy labels). An active Apple Developer Program membership and App Store Connect record are prerequisites for M4.
- **Assumptions:**
  - A single active arc per user is sufficient for v1.
  - Habits are strictly daily and binary; "3x per week" style frequency is deferred.
  - Users are willing to set up habits manually; no automatic tracking via HealthKit in v1.
  - Local notifications are enough for reminders; no push infrastructure.
  - The classic Oct–Dec window is the primary use case; other date ranges are supported but not optimised for.

## 9. Risks & Open Questions
| Risk / Question | Impact | Mitigation / Owner |
|---|---|---|
| One week for 31 FRs and 10 NFRs (35 FRs from M7) | Bugs in the core loop, or missing the submission | Specs are finalised first so implementation is mechanical; core loop (M1) is built and tested first so a partial cut is still shippable; P2 items (FR-18, 21, 25–27) are the first to drop if M3 slips |
| App Store review runs long or rejects the build | App not live by Oct 1 | Submit as early in the week as possible; keep the build free of anything reviewers flag (no login, no payments, clear notification rationale, complete privacy labels); respond to rejection within hours |
| Widget (FR-25) and photos (FR-26) add App Group and file-storage work late in the schedule | M3 overrun | Persistence is designed with an App Group from the start; photos stored as plain files in the sandbox, no library integration |
| Day rollover / time-zone edge cases corrupt streaks | Loss of trust; core metric wrong | Store entries keyed by local calendar date, not timestamps; unit-test DST and travel scenarios (NFR-5) |
| Users over-commit at setup and burn out | Low completion rate | Cap pillars at 5, warn above 7 habits (FR-5), suggest starting with 3 |
| Grace Days failure state feels punishing | Uninstalls | Keep data viewable, offer immediate restart, non-punitive copy (FR-17, FR-18) |
| Weekly-frequency habits (e.g. gym 4x/week) | Data model complexity | **Decided:** v1 habits are strictly daily and binary (data-spec §4.3); weekly frequency is a v2 item |
| Edit window default (NFR-6) | Honesty vs. convenience trade-off | **Decided:** default 7 days, user-configurable to 3 / 30 / unlimited; unlogged late-start days are always editable (data-spec §10) |
| Should the app support multiple arcs in history from v1? | Scope | Read-only archive only (FR-21, P2) |
| Widget (FR-25) requires an App Group and shared data container | Adds architectural work early | Design persistence with an App Group from the start even if the widget ships later |

## 10. Milestones
Milestones are sequential. Each is "done" when its requirements are implemented **and** their test-spec cases pass. Dates are managed by the owner outside this spec.

| Milestone | Scope |
|---|---|
| **M0 — Specs locked** | `goal-spec.md`, `frontend-spec.md`, `data-spec.md`, `test-spec.md` complete and committed. Open questions in §9 resolved. Xcode project scaffolded with persistence (App Group) and a unit-test target. |
| **M1 — Core loop** | Arc setup and daily check-in end to end: FR-1, 2, 3, 4, 5, 6, 9, 10, 11, 12, 13; NFR-1, 3, 4, 5. All three rulesets in the data layer. Unit tests for streaks, Consistency Score, rollover, DST/time-zone cases. |
| **M2 — Progress, rulesets & editing** | FR-7, 8, 14, 15, 16, 17, 22, 23, 24, 28, 29, 31; NFR-6. Progress tab, heat-map, backfill, mid-arc editing, ruleset change, Grace Days failure state and resolution, restart flow, reminders. |
| **M3 — Finish flow & extras** | FR-18, 19, 20, 21, 25, 26, 27, 30. End-of-arc summary, reflection, archive, widget, before/after photos, weekly prompt. Manual walkthrough of UJ1–UJ7. |
| **M4 — Ship** | NFR-2, 7, 8, 9, 10. Accessibility audit, performance check, localization pass, app icon, screenshots, privacy manifest and labels, App Store Connect listing. **Submit for review.** |
| **M5 — Live** | ✅ Guideline 2.1 information request answered; approved and released 29 Sep 2026. |
| **M6 — v1.1** | ✅ Approved and distributing from 3 Oct 2026. The B · Frost restyle (§12 P-1), the B-4 checkmark fix, Reduce Motion (B-1) and the review prompt. Category moved to Health & Fitness at submission. What is still open is in §12.1. |
| **M7 — The first run** | **Rescoped 6 Oct 2026 on the evidence in §12.3.** The app does not have a product problem, it has a first-run problem: most people never reach the daily loop, and the ones who do use it hard. In priority order: **FR-34 quick start**, **FR-35 reminder on by default**, then the Welcome screen itself — one of the four concepts on the onboarding canvas — and only then the **Lottie spike** (§12.2), which is now the most cuttable thing here. A prettier screen that still leads into seven steps does not fix what the numbers show. Also carries **FR-32 and FR-33**, the shareable progress card and its weekly offer — card concepts are on the share-card canvas. Sweeps up G-5, G-6, B-2 and B-3 while the backlog is this short.
**Sequencing within M7:** FR-32 and FR-33 depend on nothing else here. The Lottie spike may stall on its four criteria (§12.2) or on the MCP server that does not yet exist, and the share card must not be stuck behind it — build them in parallel, or the card first. |
| **M8 — The January arc** | Positioning for the New Year window. An arc is Oct 1 – Dec 31, so someone arriving on 2 January meets an app whose whole pitch is "enter January already ahead" — aimed at people who started three months earlier. Likely a second date preset beside Classic, copy that works year-round, and a promotional-text swap; the data layer already takes arbitrary dates. **Deadline-driven:** it must ship before late December or it is worth nothing until next autumn. Note that M7 now holds the share card, and 31 December is when the first real cohort finishes an arc — so **M7 has acquired that deadline too**, even though M8 is the milestone named for it. |

## 11. Glossary
- **Winter Arc:** A time-boxed (typically Oct 1 – Dec 31) period of intense daily discipline. See `winter-arc-concept-spec.md`.
- **Arc:** The app's top-level object: dates, pillars, habits, ruleset, and all daily entries.
- **Pillar:** A focus area grouping related habits (e.g. Physical Health). 3–5 per arc.
- **Habit:** A binary, daily non-negotiable action belonging to a pillar.
- **Entry:** The record of one habit on one calendar date: done / not done.
- **Streak:** Consecutive calendar days a habit has been marked done.
- **Consistency Score:** Done entries ÷ elapsed entries across the arc, shown as a percentage.
- **Ruleset:** The policy that defines what a missed habit costs — Streaks, Consistency Score, or Grace Days.
- **Restart:** Archiving the current arc and starting a new one pre-filled from it. Distinct from *delete*, which destroys data.
- **Arc status:** *active*, *completed*, *failed* (Grace Days exhausted), or *abandoned* (user-initiated). A failed arc is either *unresolved* (failure screen pending), *keep-going*, or *restarted*.
- **Grace day:** A permitted miss under the Grace Days ruleset.
- **The Dip:** Weeks 3–6, when drop-off is highest.
- **Day rollover:** The moment (local midnight) when the previous day is finalised and a new day begins.

## 12. v1.1 Backlog

Known gaps at the moment v1.0 was submitted. None blocked the release; all are written down
here so they survive the gap between sessions.

### Defects
| # | Item | Notes |
|---|---|---|
| B-1 | ~~Reduce Motion honoured only by the button styles~~ — **fixed.** All motion now routes through `Motion.swift`; `CONV-05` prevents regression. "Reduced Motion" can now be declared in App Store Connect once confirmed on a device. |
| B-2 | **Widget target declares iPad** | `TARGETED_DEVICE_FAMILY = "1,2"` on the widget while the app is `1`. Harmless — the widget cannot be installed without the app — but it is template residue. |
| B-3 | **iPad orientation key on an iPhone-only app** | `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad` is set, so the built plist carries portrait + upside-down. No practical effect on iPhone. |
| B-4 | ~~The done checkmark is unreadable in dark mode~~ — **fixed.** | `Checkbox.swift` drew the glyph with `.foregroundStyle(.white)` on `Color("Success")`. In dark mode `Success` resolves to #3DD68C, so the white check measured **1.88:1** — far below the 3:1 floor for a graphical object. Same defect class as the button label fixed before v1.0 (BTN-01–03): a hardcoded light colour on a token that inverts. Now `Color(.systemBackground)`, measured at **11.19:1 dark / 5.34:1 light**. Found while specifying the restyle; shipped in v1.0 and fixed for users in 1.1 (3 Oct 2026). `PAL-05` asserts the fix and `PAL-06` pins the old value below 3:1 so the regression cannot return silently; `CONV-06` will catch the whole class once the restyle lands. |

### Unverified claims
| # | Item | Notes |
|---|---|---|
| U-1 | **VoiceOver has never been exercised on a device** | Labels, values, hints and the custom "Open day details" action all exist and both audits pass, but an automated audit only proves labels are present — not that reading order or the combined habit row is usable. Declare the App Store Connect feature only after a real pass. |
| U-2 | **Voice Control** | Depends on the same labels as U-1; equally untested. |
| U-3 | **Sufficient Contrast / Differentiate Without Color Alone** | Both are defensible — the accent measures 5.45:1 light, 5.87:1 dark, 9.61:1 under Increase Contrast (BTN-01–03), and the heat map uses hatch, ring and dot cues rather than colour alone. Held back from the accessibility declaration pending a device check. The App Store Connect field is editable without resubmitting. |

### Store assets
| # | Item | Notes |
|---|---|---|
| ~~S-1~~ | ~~App preview would be far stronger on a seeded arc~~ — **resolved in 1.1.** | It recurred: the 1.1 device recording was made on a day-9 arc and ended on an empty heat map. The closing seconds were replaced with a `--seed-demo` capture showing day 34 of 92, 163 of 167 checked off. The lesson is standing — **capture store assets on a seeded arc, never on a fresh one.** |
| ~~S-2~~ | ~~Screenshot 04 is weak~~ — **resolved in 1.1.** | The Progress screenshot is now a seeded capture, and the heat map is the third frame rather than a weak fourth. |

### Deferred product work
| # | Item | Notes |
|---|---|---|
| P-1 | ~~Visual restyle~~ — **direction chosen, scheduled for 1.1.** | Three directions were mocked on the design canvas as full Today + Progress screens, then each was given its missing appearance to test whether it survives the flip: **A · Midnight** (dark, ice blue, ember streaks), **B · Frost** (light, translucent panels on a cold gradient), **C · Press** (editorial, bone paper, hard rules). Finding: A in light collapses towards B, and B in dark collapses towards A — the two blues are one direction seen from either end — while C inverts cleanly in both. **B · Frost was chosen**, styled in *both* appearances with light as the reference, so NFR-7 is unchanged. Specified in frontend-spec §6; contrast cases in test-spec §19d. |
| P-2 | **Welcome screen concepts** | "The Arc", "Ninety", "Through the Cold" were mocked and parked in favour of the shipped Arc-and-Card layout. |


## 12.1 Release gates for 1.1

Everything in the app is done and on `main`. What remains is verification that cannot be done
from a simulator, plus store assets that must be regenerated because the app no longer looks like
its screenshots.

| # | Gate | Owner | Why it blocks |
|---|---|---|---|
| ~~G-1~~ | ~~Run the restyle on a physical device~~ — **done.** | — | Frost ran on device for the 1.1 capture session; the screenshots and recording in `design/device-screenshots-1.1/` are that pass. |
| G-2 | **Scroll at 60 Hz, 7 habits × 180 days** | Vipin | No automated test exists (test-spec §19b). A translucent fill and a shadow on every card down a long list is where the restyle could cost frames. |
| ~~G-3~~ | ~~Retake all 12 screenshots~~ — **done.** | — | Six at 1290×2796 in `design/screenshots/appstore-1.1/6.9-inch/`. Not twelve: App Store Connect now uses the 6.9" set for every display size, so the 6.7" and 6.1" sets are no longer needed. |
| ~~G-4~~ | ~~Re-record the app preview~~ — **done.** | — | `design/screenshots/appstore-1.1/preview-886x1920.mp4`. App previews take 886×1920, not the screenshot size — the screenshot dimensions are rejected. |
| G-5 | VoiceOver and Voice Control pass (U-1, U-2) | Vipin | Never exercised on hardware. Gates the accessibility declaration, not the release itself. |
| G-6 | Settings `Picker` "Edit window" clipping | open | Found in the 2026-10-01 audit; a stock control that clips at default width. Not a regression from the restyle. |

Not gating: B-2 and B-3 (widget iPad target residue), P-2 (Welcome concepts).

## 12.2 M7 — what the Lottie spike has to clear

**Demoted 6 Oct 2026.** §12.3 moved the first run to the front of M7, and this spike is now the
last item in it and the first thing to cut. Do not start it until FR-34 and FR-35 are done and
measured — a dependency decision is a poor use of the weeks before January.

Lottie is the right tool for a designed particle field or three bespoke hero animations, and the
wrong one for an arc that draws itself. Which concept is chosen therefore decides whether the
dependency is needed at all: concepts A and B are native motion (a `Path` with `.trim`, a counting
number), C and D are the cases that justify a framework. **Pick the concept first, then run the
spike only if the concept needs it.**

If it is run, the spike is not finished until all four of these are answered, because each is a
claim the project currently makes and would have to retract:

| # | What it threatens | Why it is not a formality |
|---|---|---|
| 1 | **`CONV-05`** | The lint test fails the build on any animation outside `Motion.swift` and `ButtonStyles.swift`. A Lottie view autoplays and knows nothing about `accessibilityReduceMotion`. It needs a wrapper that pauses it and holds a static frame, plus an explicit exemption — and B-1 was exactly this defect class, fixed three commits before 1.1. |
| 2 | **The binary budget** | §10 of frontend-spec: "Binary < 20 MB: no bundled fonts, SF Symbols only." `lottie-ios` links around 1.5–3 MB, plus the JSON per animation. There is room; it is still the first dependency, and the first is the expensive one. |
| 3 | **The privacy manifest** | `lottie-ios` ships its own `PrivacyInfo.xcprivacy`. Frontend-spec §8 declares exactly one required-reason API and no collected data; that declaration must be re-verified against the merged manifest before submission. |
| 4 | **The App Review notes** | They state "The project has zero third-party package dependencies" and "no networking code at all". The first becomes false the moment Lottie is added and the notes must be edited. `CONV-02` must still pass with it linked — confirm it, do not assume it. |

**Tooling:** the spike is meant to use a Lottie MCP server. None is connected to this project and
none appears in the connector registry as of 3 Oct 2026, so adding one is a prerequisite of the
milestone rather than a given. Without it the animations have to come from somewhere else —
LottieFiles exports, or a designer — which is a cost worth counting before committing to C or D.

**Exit:** either Lottie is adopted with all four cleared and the notes updated, or the chosen
concept ships with native motion and the dependency is declined on the record.

## 12.3 The first-run problem (App Store Connect, 28 Sep – 4 Oct 2026)

The first week of real data. Acquisition is working; almost nobody reaches the daily loop; the
few who do use it hard. That combination is what rescoped M7.

| Metric | 28 Sep – 4 Oct | Note |
|---|---|---|
| First-time downloads | 136 | peak ~50–57 on 1 Oct, ~23/day by the 4th |
| Impressions | 2,160 | from under 100/day to ~700/day at peak |
| Conversion rate | ~30 % → **10.9 %** | the fall begins **before** 1.1 shipped on 3 Oct |
| Installations *(opt-in)* | 33 | |
| **Deletions** *(opt-in)* | **9** | **~27 % of installs deleted inside the week** |
| Sessions *(opt-in)* | 250 | |
| Active devices *(opt-in)* | ~10/day | **≈ 3.5 sessions per active device per day** |
| Day 1 retention *(opt-in)* | ~7 % | against ~25 % typical for iOS |

**What it means.** Conversion falling while impressions grow sevenfold is dilution, not a
regression — early traffic was people looking for this app by name, later traffic is browse. The
decline starting before 1.1 shipped clears the new screenshots of blame.

The real signal is the pair at the bottom: **~27 % delete within a week and Day 1 retention is
~7 %, yet the survivors open the app about three and a half times a day.** A product that failed
its users would not produce that. People are not bouncing off the daily loop — most never get to
it. Between a download and the loop sit **seven setup screens** and a reminder that is off unless
the user opts in during them, so a user who quits setup early also leaves with nothing to bring
them back. Hence FR-34 and FR-35, ahead of any visual work.

**Read these numbers with two caveats.** Sessions, devices, installations, deletions and retention
are **opt-in samples** (roughly a quarter of users), so absolute values are indicative; ratios
between two opt-in metrics — deletions against installations — are the trustworthy ones. And some
of the decay is simply the 1 October spike passing, which is normal for launch week.

**A methodology note for next time.** 1.1, the Health & Fitness category change and the new
keywords all landed within about 48 hours, so none of their effects can be separated. Change one
thing, give it a week, then change the next — otherwise the data cannot answer the question it was
collected for.

---
**Status:** v1.1 released · **Owner:** Vipin Pahwa · **Last updated:** 2026-10-03
