# Frontend Spec — Winter Arc iOS App

> Purpose: define *how* the app looks, feels, and is structured on the client.
> Every screen and component traces back to a requirement in `goal-spec.md` (FR-x / NFR-x) and a user journey (UJ-x). Data shapes referenced here are defined in `data-spec.md`; test cases in `test-spec.md`. Visual reference for the chosen direction (B · Frost, §6): the `Frost-Today` / `Frost-Progress` boards on the design canvas, and the shipped 1.1 store screenshots in `design/screenshots/appstore-1.1/`. The pre-Frost `design/today-focus.*` mockups were deleted with the restyle.

## 1. Tech Stack
| Area | Choice | Rationale |
|---|---|---|
| Language | Swift 6, strict concurrency | Current toolchain; compile-time data-race safety |
| UI framework | SwiftUI only | Fastest path for a one-week ship; declarative state maps directly to the check-in model |
| Minimum iOS | 18.0 (NFR-1) | `@Observable`, SwiftData, modern `NavigationStack`; matches the oldest simulator runtime available for testing |
| Architecture | MVVM with `@Observable` view models; thin views; services injected via environment | Testable logic outside views; no framework dependency |
| Persistence | SwiftData, store located in an **App Group** container | On-device only (NFR-4); App Group lets the widget read the same store (FR-25) |
| Dependency management | Swift Package Manager | No third-party runtime dependencies in v1 |
| Third-party libraries | None | Keeps review surface and binary size small (NFR-10) |
| Notifications | `UserNotifications` (local only) | FR-8; no push infrastructure (NFR-3) |
| Widget | WidgetKit extension sharing the App Group | FR-25 |
| Photos | `PhotosPicker` + `AVFoundation` camera capture; files stored in the App Group `Documents/Photos/` | FR-26; never written to the user's photo library unless exported |
| Unit tests | Swift Testing | Streak, score, rollover, ruleset logic |
| UI tests | None in v1 | Deferred; journeys UJ1–UJ7 verified by manual walkthrough until UI tests are added |
| Snapshot tests | None in v1 | Time-boxed; manual visual QA instead |

## 2. App Structure & Navigation
- **Navigation model:** Root switches on `ArcStore.currentArc` (data-spec §4.1: an `.active` arc, or a `.failed` arc that has not been restarted) and its *phase* (data-spec §6.9):
  - **No current arc, none ever created** → `WelcomeView` (§3.1).
  - **No current arc, but history exists** → `BetweenArcsView` (§3.12), which leads into `ArcSetupFlow`.
  - **No current arc, flag set but history deleted** → `ArcSetupFlow` directly (a `NavigationStack` of steps).
  - **Current arc, phase `failedUnresolved`** → `MainTabView` with `GraceDaysExhaustedView` presented as a full-screen cover on top; the cover is re-presented on every launch/foreground until the user chooses (FR-31).
  - **Current arc, any other phase** → `TabView` with three tabs: **Today**, **Progress**, **Settings**. Each tab owns its own `NavigationStack`. `awaitingCompletion` / `failedAwaitingCompletion` additionally present `ArcCompleteView` as a cover.
- **Modals:** sheets for day editing, reflections, photo capture, and the restart confirmation; full-screen cover for the end-of-arc summary and the Grace Days failure screen (they replace the tabs until dismissed).
- **Entry point / launch flow:** `WinterArcApp` → `RootView` shows a static launch placeholder (app mark on `LaunchBackground`, which now carries `BackdropMid`'s four values — previously #F2F2F7 / #000000, which flashed grey then black before the gradient appeared; the storyboard launch screen uses the same asset, so the hand-off from launch screen to first frame is invisible) behind a **startup gate** behind a **startup gate**: `ArcStore.open()` then `DayRolloverService.finalizeIfNeeded()` run to completion, then `RootView` reads `currentArc` + phase and routes as above. No view reads arc data before the gate clears. The same gate runs on every `scenePhase == .active` (rollover only; the store is already open) — if it produces a phase change (e.g. a new day, or exhaustion) the routing updates in place.
- **Deep links / URL scheme:** `winterarc://today` (opened by the widget and the reminder notification). No other deep links in v1.

### 2.1 Screen map
```
RootView
├─ WelcomeView                     (first launch only)
├─ ArcSetupFlow                    (no active arc)
│   ├─ DatesStep
│   ├─ PillarsStep
│   ├─ HabitsStep
│   ├─ RulesetStep
│   ├─ WhyAndReminderStep
│   ├─ BeforePhotoStep             (optional)
│   ├─ LateStartStep               (only if start date < today)
│   └─ ReviewStep → Start Arc
└─ MainTabView                     (active arc)
    ├─ Tab: Today
    │   ├─ TodayView
    │   └─ sheet: DayDetailSheet (today)
    ├─ Tab: Progress
    │   ├─ ProgressView
    │   ├─ sheet: DayDetailSheet (past day)
    │   ├─ sheet: WeeklyReflectionSheet
    │   ├─ ArchivedArcsView
    │   └─ ArchivedArcDetailView
    └─ Tab: Settings
        ├─ SettingsView
        ├─ EditHabitsView
        ├─ EditRulesetView
        ├─ RemindersView
        ├─ EditWindowView
        └─ sheets: RestartConfirmSheet, AbandonConfirmSheet, DeleteConfirmSheet

Full-screen covers (over MainTabView, driven by phase):
├─ ArcCompleteView → ClosingReflectionView → AfterPhotoView → (restart | done)
└─ GraceDaysExhaustedView → (restart | keep going | view progress)

Widget (separate target): TodayWidget (small, medium)
```

## 3. Screens

### 3.1 WelcomeView
- **Requirement(s):** UJ1 step 1
- **Purpose:** One-screen explanation of what a Winter Arc is; sets expectations before setup.
- **Entry points:** Shown while no arc exists and none has ever been created — gated on `hasCreatedArc` in the App Group `UserDefaults`, which `ArcStore.createArc` sets. Reaching the setup flow does not consume it, so abandoning setup returns here.
- **Layout / key elements:** The app icon over a drawn arc, wordmark, subtitle, then the three points (time-boxed · non-negotiables · enter January ahead) grouped in one card with dividers, and the primary button **Set up my arc**.
  - The mark is the `AppMark` imageset, built from the same artwork as `AppIcon`, clipped at the 22.37 % iOS app-icon corner ratio. SwiftUI cannot load an `.appiconset` directly, hence the separate imageset. It previously used a stock `snowflake` SF Symbol, which matched neither the icon nor the launch screen.
  - The arc and the background wash are both derived from `Color.accentColor`, so they follow the asset's light/dark/high-contrast variants rather than hardcoding a palette.
  - The mark shrinks from 84 pt to 64 pt at accessibility text sizes; the screen scrolls via `CenteredScrollView`.
- **States:** single state.
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | Tap *Set up my arc* | Push `ArcSetupFlow`. The gate is **not** closed here |
  | Abandon setup, relaunch | Welcome again — no arc was created |
- **Navigation out:** ArcSetupFlow.
- **Edge cases:** Never shown again once an arc has been created, even if that arc is later completed, abandoned or deleted — only *Reset app data* brings it back. Covered by `WelcomeGateTests` and ENV-06/07.

### 3.2 ArcSetupFlow (container)
- **Requirement(s):** G1, UJ1, FR-1–FR-8, FR-22, FR-26
- **Purpose:** Guided, linear setup that keeps the habit list small and finishes in under 3 minutes.
- **Entry points:** WelcomeView; RootView when no active arc; RestartConfirmSheet (pre-filled, FR-28).
- **Layout / key elements:** `NavigationStack`; each step has a `StepHeader` ("Step n of N · Pillars", where N is the number of steps enabled for this run — BeforePhoto and LateStart are conditional, so N is 6–8), content, and a pinned bottom `PrimaryButton` (**Continue** / **Start Arc**). Back is the standard navigation back button. A draft `ArcDraft` value type is passed through the environment and only persisted on *Start Arc*.
- **States:** editing · validating (button disabled with inline reason) · saving.
- **Edge cases:** Leaving the app mid-setup keeps the draft in memory only (not persisted) — acceptable for a 3-minute flow. When entered via restart, every step is pre-filled and the header reads "Restart arc"; **the previous arc is not touched until Start Arc** — cancelling or being terminated mid-flow leaves it current and unchanged (data-spec §11).

#### 3.2.1 DatesStep
- **Requirement(s):** FR-1, FR-2
- **Layout:** Two `DatePicker`s (start, end) in compact style; a computed caption "92 days · Oct 1 – Dec 31". Quick-pick chips: **Classic (Oct 1 – Dec 31)**, **90 days from today**, **Custom**.
- **Validation:** length 30–180 days; end > start. Inline error text below the pickers; Continue disabled while invalid.
- **Default:** Oct 1 – Dec 31 of the current year; if today is already inside that window, start = today, end = Dec 31 (if ≥ 30 days remain, else 90 days from today).

#### 3.2.2 PillarsStep
- **Requirement(s):** FR-3
- **Layout:** Grid of `PillarChip`s for the four presets (Physical Health, Mental Resilience, Career & Finances, Digital Detox) plus **+ Custom**. Preset names must satisfy the same 1–30 character rule as custom ones (data-spec §5); `PillarPresetTests` enforces it. Selected chips show a checkmark and tint. Custom opens an inline sheet: name (required, ≤ 30 chars) and SF Symbol picker (curated list of ~24).
- **Validation:** 3–5 pillars selected. Counter "3 of 5 selected". Continue disabled outside range, and the counter is replaced by the blocking reason (too few, too many, duplicate name, or name length) so a disabled Continue always explains itself.

#### 3.2.3 HabitsStep
- **Requirement(s):** FR-4, FR-5
- **Layout:** One `PillarSection` per selected pillar, each listing its habits with a swipe-to-delete, and an **Add habit** row that opens a text field with 3–5 tappable suggestions for that pillar (from a static catalogue). Total counter in the header: "5 habits".
- **Validation:** 1–3 habits per pillar (hard); total > 7 shows a non-blocking amber banner "That's a lot. Most people finish with 3–5." (FR-5). Habit names required, ≤ 40 chars, unique within the arc.

#### 3.2.4 RulesetStep
- **Requirement(s):** FR-6
- **Layout:** Three `RulesetCard`s stacked, radio-style selection. **Streaks** is pre-selected and labelled *Recommended*.
  - Streaks — "Each habit keeps its own streak. Miss a day, that streak resets. The arc keeps going."
  - Consistency Score — "Finish with your score above a target." Reveals a `Stepper` for target % (default 85, range 50–100, step 5).
  - Grace Days — "N forgiven misses. One more after that and the arc is failed." (N reflects the stepper). Reveals a `Stepper` for the budget (default 3, range 1–10).
- **Validation:** always valid.

#### 3.2.5 WhyAndReminderStep
- **Requirement(s):** FR-7, FR-8
- **Layout:** Multi-line `TextField` "Why are you doing this?" (optional, ≤ 140 chars, character counter). Toggle **Daily reminder** with a `DatePicker` (time only, default 20:00) revealed when on. Notification permission is requested on Continue only if the toggle is on.
- **Edge cases:** Permission denied → toggle turns off with caption "Enable in Settings › Notifications"; setup continues.

#### 3.2.6 BeforePhotoStep
- **Requirement(s):** FR-26 (P2)
- **Layout:** Optional. Illustration, **Take photo** / **Choose from library** / **Skip**. Preview thumbnail once captured with **Retake**.
- **Edge cases:** Camera permission denied → only library option shown. Skipping is always allowed.

#### 3.2.7 LateStartStep
- **Requirement(s):** FR-22, UJ6
- **Shown only if** start date < today. Caption "Your arc started N days ago." Three radio options: **Mark them all done** · **Mark them all missed** · **Leave blank, I'll fill them in** (default). Under Grace Days, "Mark them all missed" shows a warning if that would exhaust the budget.

#### 3.2.8 ReviewStep
- **Requirement(s):** UJ1 step 7
- **Layout:** Read-only summary grouped by section (Dates, Pillars & habits, Ruleset, Why, Reminder, Photo) — each row tappable to jump back to that step. `PrimaryButton` **Start Arc**.
- **On Start Arc:** in one save, persist `Arc` and children (and, for a restart, archive the previous arc — data-spec §11); apply late-start choice; run `applyRulesetEffects` (a `markAllMissed` late start can fail a Grace Days arc immediately); schedule the reminder if enabled; write the widget snapshot; then route by phase — normally Today at Day 1, or the countdown state if the start date is in the future, or `GraceDaysExhaustedView` if already exhausted.

### 3.3 TodayView
- **Requirement(s):** G2, G3, UJ2, FR-9, FR-10, FR-11, FR-12, FR-13, FR-17, FR-18
- **Purpose:** The daily check-in. The single most important screen; must be usable in under 30 seconds.
- **Entry points:** Tab default; widget tap; reminder notification; deep link.
- **Visual direction:** "Focus", in the Frost palette (§6) — reference board `Frost-Today` (light) / `Frost-Today-Dark`. No navigation-bar title; the hero *is* the header. The screen is a single vertical `ScrollView` over the backdrop gradient.
- **Layout / key elements:**
  1. **Hero** (`TodayHero`, top ~200 pt) — two columns. Leading: `ConsistencyRing` at 112 pt with the score ("87 %") and the word "consistency" inside. Trailing, top-to-bottom: eyebrow "WINTER ARC" (`.caption`, uppercase, `secondaryLabel`); `DayCounter` as the dominant element — "Day 34" in `.largeTitle` weight-heavy with "/ 92" in `.title3` `secondaryLabel` on the same line; a `.subheadline` line "58 days left · 2 of 5 done"; and, if set, the user's "why" in `.footnote` italic tinted accent (FR-7). Ruleset-specific element sits in place of the "why" line's trailing space or below it: Consistency Score → "Target 85 %"; Grace Days → `GraceDaysIndicator` ("2 of 3 grace days left"). Under Streaks nothing extra is shown — streaks live on the rows.
  2. **Pillar cards** — one `PillarSection` per pillar rendered as a frost panel per §6 (`CardFill` + `CardEdge`, 22 pt continuous radius, 12 pt gap, `CardShadow` in light / `CardSheen` in dark). Card header: pillar SF Symbol tinted accent, pillar name in `.subheadline` `secondaryLabel`, trailing "1 / 2" done count tinted accent. Rows inside sit directly on the card and are divided by `Hairline` — no nested fill.
  3. **`HabitRow`** — leading `Checkbox` (28 pt ring; filled `Success` circle when done, with the check glyph in **`Color(.systemBackground)`, not white** — see B-4: a white check on the dark-mode `Success` green measures 1.88:1, while `systemBackground` inverts with the fill and measures **11.19:1 dark / 5.34:1 light** against the ≥ 3:1 threshold for a graphical object — both measured at runtime by PAL-05), habit name in `.headline` (dimmed to `tertiaryLabel` when done — no strikethrough), trailing `StreakBadge` (`flame.fill` + count in **`Ember`**; hidden at 0).
  4. **Day complete banner** — appears with haptic + subtle confetti when all habits are done ("Day 34 locked in."). Reduce Motion → static banner, no confetti.
  5. **Miss message** — on the first open after a day with misses, a dismissible `MissCard` inserted between the hero and the first pillar card, with a non-punitive line and the user's "why" if set (FR-18, FR-7). Never shown more than once per day.
- **Fold budget:** on a 6.1" device at default Dynamic Type the hero plus two pillar cards (4 habits) fit above the tab bar; anything beyond scrolls. The hero collapses to a single compact row (ring at 44 pt + "Day 34 / 92") once the user has scrolled 120 pt, so the countdown stays visible while checking off a long list.
- **States:** populated · all-done · no-habits (only possible after mid-arc edit — shows CTA to Settings › Edit habits) · arc-not-started (start date in future: countdown "Starts in 3 days", habit list disabled).
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | Tap checkbox | Toggle entry for today; persisted synchronously (FR-10); haptic `.light`; streak badge updates immediately |
  | Tap habit row body | Opens `DayDetailSheet` for today (same toggles, larger targets) |
  | Pull down | No refresh (nothing to fetch); disabled |
  | Dismiss miss card | Hidden for the rest of the day |
- **Navigation out:** DayDetailSheet; tab switches.
- **Edge cases:** App open across midnight → on next foreground `DayRolloverService` finalises yesterday and the view reloads to the new day (FR-11). Time-zone change mid-arc → "today" is always the device's current local calendar date; entries keyed by date string, never timestamps (NFR-5). Grace Days exhausted during rollover → present `GraceDaysExhaustedView` as a full-screen cover on this foreground.

### 3.4 DayDetailSheet
- **Requirement(s):** FR-16, FR-22, NFR-6
- **Purpose:** View/edit a single day's entries; used for today and for past days from the heat-map.
- **Entry points:** TodayView row tap; ProgressView heat-map cell tap.
- **Layout:** Sheet, medium detent. Title = formatted date + relative label ("Yesterday"). Same `PillarSection` / `HabitRow` list as Today. Footer shows day summary "4 of 5 done".
- **States:** editable · read-only (outside edit window, NFR-6 — controls disabled, caption "Older than 7 days. Change the edit window in Settings.") · future (read-only, caption "Not yet").
- **Controls per row** (data-spec §10.1): the control depends on the habit-day state, so the user never sees an impossible transition.
  | Habit-day state | Control | Tap |
  |---|---|---|
  | Today `pending` / `done` | Checkbox | done ⇄ pending (undo deletes the entry) |
  | Past `done` / `missed` | Checkbox | done ⇄ missed (never back to pending) |
  | Past `unlogged` (late-start gap) | Segmented Done / Missed / — | First choice creates the entry; then behaves as the row above |
  Rows for habits untracked on that date are hidden. A footer caption on unlogged days reads "Not logged — fill in what happened."
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | Change a control (editable) | Persist immediately; recompute streaks/score/grace days; heat-map cell updates on dismiss |
- **Edge cases:** Under Grace Days, editing a past miss into a done refunds the grace day — and, if the failure is still unresolved, can return the arc to active (data-spec §6.7); editing a done into a miss may spend one and can trigger `GraceDaysExhaustedView` — the sheet shows an inline warning before the change takes effect.

### 3.5 ProgressView
- **Requirement(s):** G3, UJ3, FR-12, FR-13, FR-14, FR-15, FR-16, FR-21, FR-27
- **Purpose:** Where the user stands across the whole arc.
- **Entry points:** Progress tab.
- **Layout / key elements (scrolling):**
  1. **Summary card** — `ConsistencyRing` (large) with score, days completed / elapsed, and ruleset-specific line (best overall streak · distance from target · grace days used).
  2. **Heat-map** — `HeatMapView`: 7 columns (Mon–Sun), one row per week of the arc, cells 5 pt continuous-rounded and shaded by fraction of habits done (0, 1–33, 34–66, 67–99, 100 %); level 0 is `HeatEmpty` (§6), not `tertiarySystemFill`, which reads grey against the frost backdrop. Future days are outlined only. **Unlogged** days (late-start gap, data-spec §6.2) are hatched with a diagonal pattern so they are never confused with a fully-missed day. Today has a ring. Under Grace Days, days where a grace day was spent carry a small dot. Legend beneath includes the hatched "Not logged" swatch.
  3. **Pillars** — one row per pillar with a horizontal `ProgressBar` and % (FR-14).
  4. **Habits** — one row per habit: name, current streak, best streak, completion % (FR-12).
  5. **Weekly reflection** — card showing the latest note or a prompt **Write this week's reflection** (FR-27); appears from Day 7 and refreshes each Monday.
  6. **Archived arcs** — footer link, shown only if any exist (FR-21).
- **States:** populated · day-0 (arc starts today: heat-map empty, copy "Your first check-in is today").
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | Tap heat-map cell (past/today) | `DayDetailSheet` for that date |
  | Tap heat-map cell (future) | No-op |
  | Tap reflection card | `WeeklyReflectionSheet` |
  | Tap *Archived arcs* | Push `ArchivedArcsView` |
- **Edge cases:** Arcs up to 180 days → up to 26 rows; the heat-map scrolls horizontally on very small widths, otherwise the whole view scrolls vertically. Arc start mid-week → leading cells of row 1 are blank.

### 3.6 WeeklyReflectionSheet
- **Requirement(s):** FR-27 (P2)
- **Layout:** Sheet; week label, that week's score and streak highlights, multi-line text field (≤ 500 chars), **Save**. One note per ISO week; editing overwrites.

### 3.7 ArchivedArcsView / ArchivedArcDetailView
- **Requirement(s):** FR-21 (P2)
- **Layout:** List rows: date range, status pill (Completed / Failed / Abandoned), final score. Detail view is a read-only `ProgressView` layout plus the closing reflection and before/after photos if present. No editing controls anywhere.

### 3.8 SettingsView
- **Requirement(s):** FR-8, FR-23, FR-24, FR-28, NFR-6
- **Layout:** Grouped list.
  - **Arc** — Edit habits & pillars (→ `EditHabitsView`), Ruleset (→ `EditRulesetView`), Reminder (→ `RemindersView`), Edit window (→ `EditWindowView`), Your "why" (inline editable).
  - **Danger zone** — **Restart arc** (→ `RestartConfirmSheet`), **Abandon arc** (→ `AbandonConfirmSheet`), **Delete arc permanently** (destructive red, → `DeleteConfirmSheet`).
  - **About** — version, privacy note ("All data stays on this device"), acknowledgements.
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | Restart → confirm | Archive active arc as *abandoned* (or *completed*/*failed* if reached from those screens), open `ArcSetupFlow` pre-filled (FR-28) |
  | Abandon → confirm | Archive as *abandoned*; route to `ArcSetupFlow` empty |
  | Delete → type "DELETE" → confirm | Remove arc and all children; route to `ArcSetupFlow` empty |

#### 3.8.1 EditHabitsView
- **Requirement(s):** FR-23
- Same UI as `PillarsStep` + `HabitsStep` combined, operating on the live arc. Adding a habit creates no retroactive entries (past days show it as "not tracked"). Removing a habit soft-deletes it: historical entries are preserved and still count toward past scores; it disappears from Today. Changes save on **Done**.

#### 3.8.2 EditRulesetView
- Same `RulesetCard`s as setup. Changing ruleset mid-arc recomputes derived state from existing entries (e.g. switching to Grace Days counts past misses against the budget — shown as a warning with the resulting count before confirming).

#### 3.8.3 RemindersView / EditWindowView
- Reminder toggle + time; permission state caption. Edit window: segmented picker 3 / 7 / 30 days / Unlimited (default 7, NFR-6).

### 3.9 ArcCompleteView (full-screen cover)
- **Requirement(s):** G5, UJ5, FR-19, FR-20, FR-26
- **Trigger:** Rollover finalises the final day (or user completes all habits on the final day and taps **Finish arc** in the day-complete banner).
- **Layout:** Celebration header ("Arc complete."), final Consistency Score in a large ring, days completed, best streaks (top 3 habits), pillar breakdown bars, the "why" statement in a quote block. **Continue** → `ClosingReflectionView` (text field, ≤ 1 000 chars, skippable) → `AfterPhotoView` (capture/skip; shows before/after side-by-side if both exist) → final screen with **Start a new arc** (restart, FR-28) / **Done for now**.
- **Edge cases:** Under Consistency Score, header reads "Target hit" or "Arc complete" depending on outcome, never "failed". Dismissing without finishing leaves the phase at `awaitingCompletion` and re-presents the cover on next open until completed.

### 3.10 GraceDaysExhaustedView (full-screen cover)
- **Requirement(s):** UJ4, FR-17, FR-18, FR-28
- **Trigger:** Phase `failedUnresolved` (data-spec §6.9) — rollover, a past-day edit, or a `markAllMissed` late start produced one more missed day than the grace-day budget. Copy: "Out of grace days. Today's miss was one more than your N."
- **Layout:** Calm, non-punitive: "Out of grace days." One line acknowledging progress ("You still locked in 27 of 34 days.") and the "why". Buttons: **Restart with the same setup** (FR-28 — the arc is archived only when the new one is started) · **Keep going anyway** (FR-31 — sets `failureResolution = .keepGoing`; arc stays *failed* but Today remains usable; the status strip shows "Failed · tracking continues") · **View progress** (dismisses to the Progress tab without resolving; the cover returns on next foreground).

### 3.11 TodayWidget (WidgetKit)
- **Requirement(s):** FR-25 (P2)
- **Small:** "Day 34" large, "3 / 5 done" beneath, ring accent. **Medium:** adds days-left and a mini row of habit checkmarks (read-only).
- **Data:** reads the App Group SwiftData store via a lightweight snapshot written by the app on every entry change; timeline refreshes at local midnight and on each app write (`WidgetCenter.reloadTimelines`). Tapping opens `winterarc://today`.
- **States:** no active arc → "Start your Winter Arc" CTA.

### 3.12 BetweenArcsView
- **Requirement(s):** FR-21, FR-28, G5
- **Trigger:** No current arc and at least one arc in history — i.e. the previous arc was completed, abandoned, or failed-and-restarted. Reached on the launch *after* the user leaves `ArcCompleteView` via **Done for now**.
- **Purpose:** Close the loop. Before this existed the user finished a 92-day arc and met "Step 1 of 7 · Dates" on the next launch, with nothing acknowledging what they had just done.
- **Layout:** `ConsistencyRing` (128) with the previous arc's final score · headline · date range and length · two stat tiles (*n of N days locked in*, *n of N habits checked off*) · longest streak with its habit name, when non-zero · "Your last setup" card listing pillars and habit count · the "why" in a quote block.
- **Headline by outcome:** `completed` → "That's one arc down." · `failed` → "That arc got away." · `abandoned` → "That one's behind you." Walking away on day three and finishing ninety days must not read the same.
- **User actions → outcomes:**
  | Action | Outcome |
  |---|---|
  | *Start your next arc* | `ArcSetupFlow(prefill:)` seeded from the previous arc via `ArcStore.restartDraft`. **Not** a restart: the previous arc is already archived and is never touched again |
  | *Change the setup* | `ArcSetupFlow` with an empty draft |
  | *View past arcs* | `ArchivedArcsView` as a sheet |
- **Navigation out:** ArcSetupFlow, or the archive sheet. Creating an arc routes to `MainTabView`.
- **Edge cases:** If the entire history is deleted the screen has nothing to show, and routing falls through to `ArcSetupFlow`; `hasCreatedArc` stays set, so the Welcome pitch does not return. Covered by ENV-16–19 and `BetweenArcsTests`.


### 3.13 Buttons (HIG › Buttons)
- **Press state is mandatory.** "Without a press state, a button can feel unresponsive, making people wonder if it's accepting their input." Every style in §4 defines one. Fifteen custom buttons previously used `.buttonStyle(.plain)`, which strips the default styling without substituting feedback.
- **One prominent button per view.** `DepthButtonStyle` is the only filled style; secondary and tertiary carry the rest.
- **Style, not size, marks the preferred option** — all actions in a stack share a width.
- **Depth is applied by darkening `AccentColor`, never by substituting a colour.** This keeps the asset's dark-mode and Increase-Contrast variants, and makes the accent itself the button's lightest point, so label contrast is never worse than the accent's own.
- **The label is `systemBackground`, not white.** The accent inverts in dark mode (it resolves to a light blue), where white measures ~2.6:1. `systemBackground` inverts with it: white label on the dark accent, black on the light one. Measured by BTN-01–03.
- **Destructive actions never take the prominent style**, per HIG; they use `role: .destructive`.
- **Scale is motion.** Styles that scale on press fall back to no movement under Reduce Motion.
- **All motion goes through `Motion.swift`.** `calmAnimation`, `calmTransition` and `Motion.animated` each drop to no animation (transitions to a plain cross-fade) when Reduce Motion is on. `CONV-05` fails the build if `.animation`, `.transition` or `withAnimation` appears outside `Motion.swift` and `ButtonStyles.swift`. v1.0 shipped with only the button styles honouring the setting.

### 3.14 App Store review prompt
- **Requirement(s):** none in v1.0 — added in v1.1.
- **Trigger:** the first time the user completes a seventh consecutive **complete day** (every tracked habit done), detected in `TodayView.toggle` where the day-complete celebration already fires. Delayed 1.5 s so the "Day n locked in" banner lands first.
- **Policy:** `ReviewPrompt.shouldAsk(hasAsked:completeDayStreak:)` — a pure function, so it is testable without StoreKit, which cannot be driven from a test. The app asks **at most once** (`hasAskedForReview`); Apple throttles separately at three prompts per user per year and decides whether anything is shown at all.
- **Why a seven-day run, not arc completion:** completing an arc is the stronger moment, but on a 90-day challenge only a small fraction of users reach it, which would waste a mechanism Apple limits so tightly.
- **The flag is set before the request, not after.** The system may show nothing and reports no result, so a user who is never shown the sheet must not be re-asked on every later completion.
- **Never from a button.** App Review forbids a "Rate us" control wired to `requestReview`; a manual path would have to deep-link to the App Store product page instead.
- **Edge cases:** `Reset app data` clears the flag. Covered by REV-01–05 and the `--seed-review` launch argument.

## 4. Reusable Components
| Component | Used on | Props / inputs | Notes |
|---|---|---|---|
| `PrimaryButton` | Setup, covers, sheets | title, isEnabled, action | Full-width, 50 pt, `DepthButtonStyle`; disabled = 50 % opacity |
| `DepthButtonStyle` | The one prominent action per view | — | `AccentColor` fill, shaded downwards, hairline top sheen, accent-tinted shadow. **Press:** shading deepens, shadow collapses to 1 pt, scale 0.972 (dropped under Reduce Motion) |
| `SecondaryButtonStyle` | Second-rank actions | — | Accent at 12 % fill, 50 pt. **Press:** fill to 22 %, scale 0.98 |
| `TertiaryButtonStyle` | Quietest actions | — | Text only, 44 pt. **Press:** opacity 0.55 |
| `PressableCardStyle` | Habit rows, pillar/ruleset/date cards, review rows, heat-map cells | scale | Replaces `.buttonStyle(.plain)`, which had no press state. **Press:** opacity 0.62, scale 0.985 |
| `StepHeader` | Setup steps | step index, total, title | Progress dots + title |
| `PillarChip` | PillarsStep, EditHabits | pillar, isSelected | Toggle style; 44 pt min height |
| `PillarSection` | Today, DayDetail, HabitsStep, EditHabits | pillar, habits, entries, isEditable, style (card / list) | Card style on Today (rounded, 16 pt); list style elsewhere. Header: symbol + name + "n / m" |
| `HabitRow` | PillarSection | habit, isDone, streak, isEditable, onToggle | Whole row tappable; checkbox is the accessibility element |
| `Checkbox` | HabitRow | isOn | Custom 28 pt circle → filled check; 44 pt hit target |
| `StreakBadge` | HabitRow, Progress | count | `flame.fill` + count in `secondaryLabel`; hidden when 0 |
| `TodayHero` | Today | arc, metrics, why, ruleset | Ring + day counter + subline + "why"; collapses on scroll |
| `DayCounter` | TodayHero, Widget | dayIndex, totalDays, style (hero / compact) | Hero: "Day 34" + "/ 92"; compact: "Day 34 / 92" |
| `ConsistencyRing` | TodayHero, Progress, ArcComplete, Widget | score (0–1), size (112 / 64 / 44), target?, showsLabel | Circular progress, 10 pt stroke at 112; optional target tick; label "87 %" + "consistency" inside at hero size |
| `GraceDaysIndicator` | Today, Progress | used, budget | Filled/hollow dots + label |
| `RulesetCard` | RulesetStep, EditRuleset | ruleset, isSelected, config binding | Radio card with expandable config |
| `HeatMapView` | Progress, ArchivedArcDetail | arc, entries, onSelectDate | 7-column grid; 5-level shading; today ring; grace dot |
| `ProgressBar` | Progress (pillars) | fraction, tint | Rounded, 8 pt |
| `MissCard` | Today | message, why, onDismiss | Non-punitive copy; dismissible |
| `EmptyState` | Various | symbol, title, message, action? | Centered illustration + CTA |
| `StatusPill` | Archived list | status | Completed / Failed / Abandoned colours |

## 5. State Management & Data Flow
- **Concurrency model (Swift 6):** the app target builds with default `@MainActor` isolation (Xcode setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). All SwiftData access goes through the container's `mainContext` on the main actor; no `@ModelActor`, no background contexts, and model objects never cross an actor boundary. `ArcMetrics` and `DateKey` are `Sendable` value types / pure functions with no SwiftData dependency, so tests can call them from any isolation. `PhotoStore` image downscaling is the one `nonisolated async` operation and returns `Data`, not a model.
- **Source of truth:** SwiftData `ModelContainer` in the App Group. Models per `data-spec.md`: `Arc`, `Pillar`, `Habit`, `DailyEntry`, `Reflection`, `Photo`.
- **Derived state:** streaks, Consistency Score, per-pillar %, grace days used, arc status transitions are computed by pure functions in `ArcMetrics` (no SwiftData dependency) so they are unit-testable. View models call them and cache results per render.
- **View model responsibilities:**
  - `RootViewModel` — resolves active arc, runs `DayRolloverService.finalizeIfNeeded()` on launch and `scenePhase == .active`, routes to setup / tabs / covers.
  - `ArcSetupViewModel` — owns `ArcDraft`, validation per step, commit.
  - `TodayViewModel` — today's entries, toggle, day-complete detection, miss-card logic.
  - `ProgressViewModel` — heat-map data, metrics, reflections.
  - `SettingsViewModel` — edit/restart/abandon/delete flows.
- **Services (protocols, injected via `@Environment`, mocked in tests):** `ArcStore` (SwiftData CRUD), `DayRolloverService`, `NotificationScheduler`, `PhotoStore`, `WidgetRefresher`, `Clock` (injectable "now" for tests).
- **Persistence read/write points:** every checkbox toggle writes immediately (FR-10, NFR-5); setup writes once on Start Arc; reflections on Save; settings changes on Done/toggle. After every write: `WidgetRefresher.reload()`.
- **Day rollover (FR-11, NFR-5):** inside the startup gate (§2) on launch and on every foreground; for every date after `arc.rolloverCursorDateKey` up to yesterday (skipping the late-start unlogged range), mark missing entries as `.missed`, apply ruleset effects, advance the cursor. Idempotent — re-running on the same date is a no-op. Uses an explicit Gregorian `Calendar` with the injected time zone; entries are keyed by `yyyy-MM-dd` strings. Full algorithm: data-spec §7.
- **Background:** no background tasks. Rollover is lazy (next foreground). The widget timeline entry at midnight simply shows "0 / n done" for the new day.

## 6. Design System
Follows Apple's Human Interface Guidelines (Designing for iOS, Materials, Color). Where the HIG and this section disagree, the HIG wins.

- **Theme:** "Frost" — calm, sparse, high contrast, layered. The direction was chosen from three mocked alternatives (Midnight / Frost / Press) on the design canvas; Frost won. **Light is the design reference** (`Frost-Today`, `Frost-Progress` on the canvas) and dark is its counterpart (`Frost-Today-Dark`); both are fully supported and verified per screen, as NFR-7 requires. Personality comes from three things: a cold backdrop gradient, content cards that sit on it as translucent panels with a bright edge, and one warm accent reserved for streaks. The oversized day counter carries the rest.
- **Two surface layers.** Frost replaces the flat grouped-background stack with a backdrop and a card layer. **Text stays on system semantic colours** — that is what keeps Increase Contrast, Bold Text and the accessibility settings working, and it is not negotiable.
  | Role | Colour |
  |---|---|
  | Backdrop (every screen, behind everything) | three-stop vertical gradient `BackdropTop` → `BackdropMid` (44 %) → `BackdropBase` |
  | Cards, rows, sheets | `CardFill` over the backdrop, 1 pt `CardEdge` border, 22 pt continuous radius |
  | Card depth | light: shadow `CardShadow`, 0 / 8 / 26; dark: inset top highlight `CardSheen`, no outer shadow |
  | Nested groups (e.g. habit rows inside a pillar card) | no second fill — rows sit directly on the card, divided by `Hairline` |
  | Primary / secondary / tertiary text | `label` / `secondaryLabel` / `tertiaryLabel` |
  | Separators inside cards | `Hairline` (not system `separator`, which disappears on a translucent panel) |
  | Placeholder text | `placeholderText` |
  - **The backdrop is applied per screen**, not once at the root. This was tried the other way first and does not work: a background set above `TabView` / `NavigationStack` is painted over by them, so every screen went flat white. It has to sit on the screen's own content, inside the navigation stack. Sheets and full-screen covers are separate window layers and need their own regardless, so the per-screen rule is uniform rather than a special case. The cost is one `.arcBackdrop()` per screen — fifteen call sites — which `CONV-06` does not police; a screen that forgets it shows system white, and that is what the light/dark pass in §20 is for.
  - **`List` and `Form` are opaque** and hide the backdrop entirely, so each sets `.scrollContentBackground(.hidden)`. Their rows keep the system's own inset-grouped background rather than `CardFill`: overriding it with `.listRowBackground` flattens the inset-card geometry to full-bleed rows, which costs more than the translucency gains. Settings, Reminders, Edit habits, Past arcs and the day sheet therefore read as system cards on the Frost backdrop.
  - Navigation bars, the tab bar, sheets and alerts keep their system backgrounds and are *not* given the gradient — they must stay free to adopt Liquid Glass on iOS 26.
  - **`CardFill` is translucent** (white at 76 % in light, white at 6.5 % in dark), so the resolved card colour changes with the backdrop stop behind it. Every contrast figure for content on a card is therefore measured against **both extremes of the backdrop gradient** in each appearance, not against one nominal surface. See test-spec §19d.
  - **Under Increase Contrast** the card gradient flattens: `CardFill` resolves opaque, `CardEdge` and `Hairline` rise to 30 %, and `CardSheen` and `CardShadow` go to zero. The frost look is a preference, legibility is not.
  - **`CardEdge` inverts its hue in light Increase Contrast**, to `#0C1A2E` at 30 %. "Rise to 30 %" is not enough on its own: the standard light rim is *white*, and white at any alpha over a white card is invisible, so raising the opacity alone would have produced no border at all. Dark mode keeps a white rim and only the alpha changes. This is the one place the two appearances are not mirror images.
- **Custom colour tokens** (asset catalog; each defines **light, dark, light-high-contrast, dark-high-contrast** as the HIG requires — including the ones used in only one appearance, which carry alpha 0 in the other). Everything not listed here is a system colour.
  | Token | Light | Dark | Use |
  |---|---|---|---|
  | `AccentColor` | #2563D8 | #6FA0FF | App accent: prominent button backgrounds, rings, selected state, tab tint |
  | `BackdropTop` | #F7FAFF | #1B2738 | Backdrop gradient, 0 % |
  | `BackdropMid` | #EAF1FC | #16202F | Backdrop gradient, 44 % |
  | `BackdropBase` | #E4ECF9 | #121A27 | Backdrop gradient, 100 % |
  | `CardFill` | #FFFFFF @ 76 % | #FFFFFF @ 6.5 % | Card fill, translucent over the backdrop |
  | `CardEdge` | #FFFFFF @ 95 % | #FFFFFF @ 14 % | 1 pt card border — the bright rim that reads as glass |
  | `CardSheen` | — (alpha 0) | #FFFFFF @ 12 % | Inset 1 pt top highlight on cards, dark only |
  | `CardShadow` | #1A3A78 @ 10 % | — (alpha 0) | Card shadow, light only |
  | `Hairline` | #0C1A2E @ 7 % | #FFFFFF @ 9 % | Dividers between rows inside a card |
  | `Success` | #157A52 | #3DD68C | Done checkbox, day-complete banner |
  | `Ember` | #A8501E | #FF9A5E | **Streaks only** — `flame.fill` and its count. Nothing else. |
  | `Warning` | #8A5A00 | #FFB340 | Habit-count banner, grace-day warning |
  | `Danger` | #C4221A | #FF6B61 | Delete, *Failed* status pill |
  | `HeatEmpty` | accent at 9 % | accent at 10 % | Heat-map level 0 — replaces `tertiarySystemFill`, which reads grey against the frost backdrop. **Derived in code**, not a colorset, so it follows the accent's own four variants |
  | `HeatLow` / `HeatHigh` | accent at 25 % → accent at 100 % | same | Heat-map ramp endpoints; levels 1–4 interpolate. **Derived in code**, as they already are in `HeatMapView` |
  High-contrast variants darken (light) / lighten (dark) each value by ~15 % L* and are verified at ≥ 4.5:1 against their surfaces.
  `AccentColor`, `Success`, `Warning` and `Danger` keep the values that shipped in v1.0 — the Frost mockup's accent (#2F6BD8 light / #7FB6FF dark) is within noise of the existing token, which is measured at 5.45:1 light, so it is not churned. The four light values above were corrected on 2026-10-01: they had been darkened in the asset catalogue during the M4 audit (§20, "Warning, Success, Danger and Accent darkened to clear 4.5:1") but this table still carried the pre-audit figures. Read the catalogue, not this table, if they ever disagree again.
  **`Ember` is darker than the mockup.** The board uses #C2622F in light, which measures **3.85:1** on a `CardFill` panel — below AA for the streak count, which is text. #A8501E measures **5.11:1**. The dark value needs no adjustment (**6.72:1**).
- **Colour usage rules (HIG › Color):**
  - One colour, one meaning. Accent = interactive/selected; Success = done; **Ember = momentum (streaks, and only streaks)**; Warning = caution; Danger = destructive/failed.
  - Never use accent for non-interactive decoration. A decorative arc was drawn behind the Today hero during the restyle and removed on 2026-10-01: faithful to the board, but at real size its stroke crossed the consistency ring and read as a stray line rather than a background. The rule has no exceptions again.
  - **No colour literals in views.** Every colour resolves from the asset catalog or a system semantic colour. Hardcoding sRGB values silently discards the dark-mode and Increase-Contrast variants — this has already shipped twice in this project (the button gradient, and the white checkmark in B-4). Enforced by `CONV-06`.
  - At most **one** accent-filled control per screen (the primary action). Everything else is tinted text/symbols or plain.
  - Never convey information by colour alone: heat-map cells also carry a numeric label on tap and VoiceOver value; under Increase Contrast, cells additionally show 0–4 small dots; the *Failed* pill has text; the done checkbox changes shape (empty ring → filled check), not just colour.
  - Tab bar and toolbar symbols stay monochrome (system default); only the selected tab is tinted.
- **Materials & Liquid Glass (HIG › Materials):**
  - Navigation and controls — `TabView`, `NavigationStack` bars, sheets, alerts, `Button` styles — are standard system components and adopt Liquid Glass automatically on iOS 26 and the classic appearance on iOS 18. We do not customise their backgrounds.
  - **No `glassEffect` in the content layer — the frost look is painted, not Liquid Glass.** `HabitRow`, `PillarSection`, `HeatMapView`, `ConsistencyRing`, cards, and the widget never call `glassEffect`. The translucent-panel appearance is built from `CardFill` + `CardEdge` + `CardSheen`/`CardShadow`, which (a) renders identically on iOS 18 and 26, (b) yields a resolved colour we can measure for contrast, and (c) cannot be restyled under us by a future system change. **No material in the content layer either.** The exception previously carved out here — `.regularMaterial` behind the miss card and the day-complete banner "when they overlay scrolling content" — described something the app never did: both are inserted inline in Today's stack, not floated over it. Over the backdrop gradient a material also reads muddy rather than frosted. Both are ordinary cards now, and the rule is absolute.
  - The single prominent action per screen (`Start Arc`, `Continue`, `Save`) uses `.buttonStyle(.borderedProminent)` so the system applies the accent to the control background — the HIG-recommended way to emphasise a primary action on glass.
  - Scroll-edge effects are left to the system; content is laid out so its resting state at the top of the screen is legible under the navigation bar.
- **Typography:** SF Pro via system text styles only (`.largeTitle` `.heavy` for the hero day counter, `.title2` section headers, `.headline` habit names, `.subheadline` pillar names, `.body` copy, `.caption` / `.footnote` metadata). No fixed point sizes; all Dynamic Type (NFR-7). Numerals in counters and rings use `.monospacedDigit()` so they don't jitter. Letter-spacing is tightened (`.kerning(-1)`) on the hero counter only.
- **Layout (HIG › Designing for iOS):** primary actions live in the bottom half of the screen (pinned `PrimaryButton`, checkboxes on the trailing edge of rows); secondary actions are reached by swipe (row swipe-to-delete) or the navigation bar. Limit visible controls: Today shows the habit list and nothing else above the fold. Safe-area and keyboard insets are respected via system containers.
- **Spacing:** 4-pt base; standard insets 16 pt; card padding 16 pt; list row min height 56 pt.
- **Corner radius:** system defaults for buttons; **22 pt continuous** for every content card (pillar cards, `ConsistencyRing` card, `MissCard`, summary cards) — one value, stated once here, superseding the 12 pt and 16 pt figures that previously disagreed between this section and §3.3; 5 pt continuous for heat-map cells; 3 pt for progress bars and legend swatches; full circle checkboxes.
- **Iconography:** SF Symbols only, rendered with the default monochrome style; hierarchical rendering for the pillar symbol in section headers. Streaks use `flame.fill` (never the emoji) so they tint and scale with the system. Pillar defaults: `figure.strengthtraining.traditional`, `brain.head.profile`, `briefcase`, `iphone.slash`. Custom pillars pick from a curated list of 24.
- **Motion & haptics:** checkbox toggle — 150 ms spring + `.light` impact; day complete — 400 ms scale-in banner + `.success` notification haptic + confetti (skipped under Reduce Motion); tab and navigation transitions are system default. No looping animations.
- **Appearance:** light and dark fully supported and verified per screen — light is the design reference, which also matches the App Store screenshots already captured. Increase Contrast verified on Today, Progress, and Setup, including the flattened card treatment. The widget follows the system and uses the same tokens, but draws no backdrop gradient.

## 7. Accessibility (NFR-7)
- **VoiceOver:** every `HabitRow` is one element: label "Gym, streak 12, not done", trait `.button`, hint "Double tap to mark done". `HeatMapView` cells: "October 5, 4 of 5 habits done". Rings expose value as percentage. Decorative confetti and illustrations are hidden.
- **Dynamic Type:** all text scales; at accessibility sizes `HabitRow` wraps to two lines and the status strip stacks vertically. Heat-map cell size is fixed but the legend scales.
- **Contrast:** all custom tokens ≥ 4.5:1 for text, ≥ 3:1 for UI components, in light, dark, and both Increase Contrast variants. Because `CardFill` is translucent, content on a card is measured against the resolved colour at **both extremes of the backdrop gradient** (`BackdropTop` and `BackdropBase`) — a single nominal surface would hide the worst case. Verified by the palette suite, test-spec §19d. Heat levels are distinguishable without colour (numeric label on tap, VoiceOver value, 0–4 dots under Increase Contrast; today ring; grace dot).
- **Decoration is hidden:** confetti and illustrations are `accessibilityHidden(true)`.
- **Reduce Motion:** no confetti, crossfades instead of springs.
- **Touch targets:** every control ≥ 44 × 44 pt.
- **Other:** Bold Text, Increase Contrast, and Button Shapes honoured via system components; no custom gestures without a button alternative.

## 8. Notifications & System Integrations
- **Local notifications (FR-8):** exactly one pending request, identifier `daily-reminder`, `UNCalendarNotificationTrigger(dateMatching: hour/minute, repeats: true)`. Content is fixed — title "Winter Arc", body "Time to check in on today's non-negotiables." — because a repeating request cannot vary per day and cancelling it cancels all repeats. It is (re)scheduled when the toggle is turned on, on Start Arc, on restart, and when the time is changed; it is removed when the toggle is turned off, on abandon, delete, completion, and when a failed arc stops being current. Rollover and entry changes never touch it. Permission requested only when the user turns the toggle on; `provisional` not used.
- **Widget (FR-25):** see §3.11. App Group ID `group.<bundle-id>`.
- **Photos (FR-26):** camera and photo-library *add-only* access; images downscaled to ≤ 1 600 px longest edge and stored as HEIC in the App Group. Never written to the library unless the user taps **Save to Photos** on the after-photo comparison.
- **HealthKit / Screen Time:** none (non-goal).
- **Permissions & rationale strings (Info.plist):** `NSCameraUsageDescription` — "Take your before and after photos."; `NSPhotoLibraryAddUsageDescription` — "Save your before/after comparison." (iOS has no Info.plist key for notifications; the rationale is shown in-app on the reminder toggle before requesting permission.)
- **Privacy manifest:** declares no tracking, no data collection, and one required-reason API: `NSPrivacyAccessedAPICategoryUserDefaults` with reason `1C8F.1` (App Group `UserDefaults` shared with the widget). The app does not use the standard (non-group) defaults.

## 9. Error Handling & Empty States
| Scenario | UI treatment | Recovery action |
|---|---|---|
| SwiftData write fails on toggle | Checkbox reverts; toast "Couldn't save. Try again." | Retry on next tap; log locally |
| Store fails to open on launch | Full-screen error with **Try again** and **Reset app data** (destructive, double-confirm) | Reset recreates an empty store |
| Notification permission denied | Toggle off + caption linking to Settings | Deep link to app settings |
| Camera unavailable / denied | Hide camera option; library only | — |
| No active arc (after abandon/delete) | `ArcSetupFlow` with empty draft | — |
| Arc with zero habits after editing | `EmptyState` on Today: "No habits yet" → Settings › Edit habits | — |
| Arc start date in the future | Today shows countdown; list disabled | — |
| Date jumps backwards (manual clock change) | Finalised days are never un-finalised; today resolves to the device date; a caption warns "Your device date looks earlier than your last check-in" | — |

## 10. Performance & Quality Targets (NFR-2, NFR-9, NFR-10)
- Cold launch to interactive Today < 1 s on iPhone 12, with the startup gate (§2) budgeted at < 300 ms typical (store open + a one-day rollover). Worst case — a 90-day catch-up × 7 habits, i.e. 630 inserts in one save — must complete in < 1 s and is part of the manual QA checklist. The gate shows a static placeholder, never stale data.
- Every interaction < 100 ms: metrics computed with O(days × habits) pure functions; heat-map built once per data change and cached in the view model.
- No frame drops on scroll at 60 Hz with 7 habits × 180 days.
- Memory: photos loaded as downsampled thumbnails; full-size only in the comparison view.
- Binary < 20 MB: no bundled fonts, SF Symbols only, assets in the catalog with app thinning.
- The Frost treatment adds no measurable cost: the backdrop is one `LinearGradient` per screen (not per cell or per row) and card translucency is a flat fill with alpha — no blur, no `glassEffect`, no per-frame blending. Scroll performance targets above are unchanged and must be re-measured once the restyle lands.

## 11. Testing Strategy
Detailed cases live in `test-spec.md`; each cites the FR/NFR it verifies.
- **Unit (Swift Testing):** `ArcMetrics` (streaks incl. best, Consistency Score, per-pillar %, grace-day accounting incl. refunds on edit), `DayRolloverService` (idempotency, multi-day gaps, DST forward/back, time-zone travel, clock rollback), draft validation, ruleset switch recomputation, late-start application.
- **UI tests:** deferred. Views still carry stable accessibility identifiers so XCUITest coverage of UJ1–UJ7 can be added later without UI changes.
- **Manual QA checklist:** walk through every journey UJ1–UJ7; every screen in light/dark × default/AX3 Dynamic Type; VoiceOver pass on Today, Progress, Setup; edit-window read-only state; widget deep link and after-midnight refresh; Reduce Motion path; notification body accuracy; App Store screenshots captured on 6.7" and 6.1".

## 12. Resolved Decisions
- Heat-map for 180-day arcs: accept the vertical length (up to 26 rows); the whole Progress view scrolls.
- Per-day notes on habits: not in v1 (no FR); `DayDetailSheet` has no note field.
- Arc name: the arc is identified by its date range; no name field.
- "Keep going anyway" after Grace Days failure: kept, now FR-31.

---
**Status:** Draft v4 · **Owner:** Vipin Pahwa · **Last updated:** 2026-10-01 (§6 restyled to B · Frost)
