# Data Spec — Winter Arc iOS App

> Purpose: define exactly *what is stored* and *how every number is computed*. This is the contract between the persistence layer, the view models, the widget, and the unit tests. Requirements referenced as FR-x / NFR-x come from `goal-spec.md`; screens as §x.y from `frontend-spec.md`.

## 1. Principles
1. **On-device only.** Single SwiftData store in the App Group container. No network, no sync (NFR-3, NFR-4).
2. **Calendar dates, not timestamps.** Every day-level fact is keyed by a `DateKey` string `yyyy-MM-dd` in the device's *local* calendar at the moment it was written. Timestamps (`Date`) are stored only as audit metadata (NFR-5).
3. **Facts are stored; metrics are derived.** Streaks, Consistency Score, grace-day usage, and arc phase are never persisted. They are pure functions of the stored entries and are recomputed on demand (`ArcMetrics`). This keeps them unit-testable and makes backfill edits automatically consistent.
4. **Never destroy history silently.** Habits are soft-deleted; arcs are archived; only an explicit "Delete permanently" removes rows.
5. **Idempotent rollover.** Finalising a day twice must produce the same state as finalising it once.

## 2. Primitive Types
| Type | Definition |
|---|---|
| `DateKey` | `String` matching `^\d{4}-\d{2}-\d{2}$`, produced by an explicit `Calendar(identifier: .gregorian)` whose `timeZone` is the injected device time zone — never `Calendar.current`, whose identifier follows the user's locale (Japanese, Buddhist, …). Lexicographic order == chronological order. Helpers: `DateKey.today(clock:calendar:)`, `.adding(days:)`, `.daysBetween(_:_:)`, `.weekday`. |
| `Ruleset` | `enum { streaks, consistencyScore, graceDays }` — `String` raw values for storage. |
| `ArcStatus` | `enum { active, completed, failed, abandoned }` — stored. See §6 for the derived *phase*. |
| `FailureResolution` | `enum { keepGoing, restarted }` — stored on a `.failed` arc once the user has answered the exhaustion screen; nil while the failure is *unresolved*. |
| `EntryState` | `enum { done, missed }` — stored. The *absence* of an entry is meaningful; see §4.4. |
| `LateStartChoice` | `enum { markAllDone, markAllMissed, leaveBlank }` — transient, never stored. |
| `ReflectionKind` | `enum { weekly, closing }` |
| `PhotoKind` | `enum { before, after }` |
| `WeekKey` | `String` `YYYY-'W'ww` — ISO 8601 **week-based year** (`yearForWeekOfYear`) and week number from the `.iso8601` calendar, e.g. `2026-W41`. Note `YYYY`, not `yyyy`: 2024-12-31 is `2025-W01`, 2027-01-01 is `2026-W53`. |

## 3. Storage Layout
| Store | Location | Contents |
|---|---|---|
| SwiftData `ModelContainer` | `<AppGroup>/Library/Application Support/WinterArc.store` | All models in §4 |
| Photo files | `<AppGroup>/Documents/Photos/<photoId>.heic` | Downscaled HEIC ≤ 1 600 px longest edge (FR-26) |
| Widget snapshot | `<AppGroup>/Library/Application Support/widget-snapshot.json` (not `Caches`, which the system may purge); written atomically | §8 |
| `UserDefaults(suiteName: <AppGroup>)` | — | §9 |

App Group identifier: `group.<bundle-id>`. Both the app and the widget extension have the entitlement.

## 4. Models (SwiftData)

### 4.1 `Arc`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Primary key |
| `startDateKey` | `DateKey` | Inclusive |
| `endDateKey` | `DateKey` | Inclusive. `length = daysBetween(start, end) + 1`, 30 ≤ length ≤ 180 (FR-2) |
| `ruleset` | `Ruleset` | FR-6 |
| `consistencyTarget` | `Int?` | 50…100, step 5, default 85. Required iff `ruleset == .consistencyScore` |
| `graceDayBudget` | `Int?` | 1…10, default 3. Required iff `ruleset == .graceDays` |
| `whyStatement` | `String?` | ≤ 140 chars, trimmed, nil if empty (FR-7) |
| `reminderHour` / `reminderMinute` | `Int?` | Both nil ⇒ reminders off (FR-8) |
| `status` | `ArcStatus` | Default `.active` |
| `rolloverCursorDateKey` | `DateKey?` | Highest date that rollover (§7) has processed. nil ⇒ rollover has never run |
| `unloggedThroughDateKey` | `DateKey?` | Set only by late-start *leaveBlank* (§7.3) to `today − 1` at creation. Dates in `[startDateKey, unloggedThroughDateKey]` are exempt from rollover and read as `unlogged` until the user backfills them. nil otherwise |
| `failureResolution` | `FailureResolution?` | nil while `status != .failed` and while a failure is unresolved; `.keepGoing` or `.restarted` once the user chooses on `GraceDaysExhaustedView` (FR-31) |
| `createdAt` | `Date` | Audit |
| `endedAt` | `Date?` | Set when status leaves `.active` |
| `pillars` | `[Pillar]` | Cascade delete |
| `reflections` | `[Reflection]` | Cascade delete |
| `photos` | `[Photo]` | Cascade delete; files removed by `PhotoStore` |

**Invariants**
- At most one `Arc` with `status == .active` (enforced by `ArcStore.createArc`, which refuses if one exists).
- `startDateKey ≤ endDateKey`.
- `rolloverCursorDateKey`, when set, is in `[startDateKey, endDateKey]`.
- `unloggedThroughDateKey`, when set, is in `[startDateKey, endDateKey]` and `< today` at the time it is set; it is never moved later (backfilling creates entries; it does not shrink the range).
- `failureResolution != nil ⇒ status == .failed`.
- **Current arc** (the one the UI operates on): `isCurrent = status == .active || (status == .failed && failureResolution != .restarted)`. At most one arc is current at any time; `ArcStore.currentArc` returns it.
- `pillars.count` is 3…5 at creation (FR-3). Mid-arc edits may reduce below 3 only via soft-delete of all habits in a pillar; a pillar with zero active habits is hidden, not deleted.

### 4.2 `Pillar`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `arc` | `Arc` | Inverse of `Arc.pillars` |
| `name` | `String` | 1…30 chars; unique (case-insensitive) within the arc |
| `symbolName` | `String` | SF Symbol name from the curated list; presets have fixed symbols |
| `presetKey` | `String?` | `physical`, `mental`, `professional`, `digital`, or nil for custom |
| `sortOrder` | `Int` | Display order |
| `habits` | `[Habit]` | Cascade delete |

### 4.3 `Habit`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `pillar` | `Pillar` | |
| `name` | `String` | 1…40 chars; unique (case-insensitive) among *active* habits in the arc |
| `sortOrder` | `Int` | |
| `trackedFromDateKey` | `DateKey` | First date this habit counts. `= arc.startDateKey` for habits created at setup; `= today` for habits added mid-arc (FR-23) |
| `trackedUntilDateKey` | `DateKey?` | Exclusive. nil ⇒ still active. Soft-delete (FR-23) sets it to `today + 1` if an entry already exists for today (so that entry stays valid and counts), otherwise `today`. The habit disappears from Today; its past entries remain and still count |
| `entries` | `[DailyEntry]` | Cascade delete |

**Derived:** `isActive = trackedUntilDateKey == nil`. `isTracked(on d) = trackedFromDateKey ≤ d && (trackedUntilDateKey == nil || d < trackedUntilDateKey)`.

**Invariants**
- 1…3 active habits per pillar at setup (FR-4). Total active habits > 7 is allowed but warned (FR-5).
- `trackedFromDateKey ≥ arc.startDateKey`.

### 4.4 `DailyEntry`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `habit` | `Habit` | |
| `dateKey` | `DateKey` | Within `[arc.startDateKey, arc.endDateKey]` and within the habit's tracked range |
| `state` | `EntryState` | `done` or `missed` |
| `source` | `enum { user, rollover, lateStart }` | Audit; `rollover` and `lateStart` entries are always `missed` or `done` in bulk |
| `updatedAt` | `Date` | |

**Uniqueness:** exactly zero or one entry per `(habit, dateKey)`. Enforced by `ArcStore.setEntry`, which upserts.

> **Naming:** "habit-day" is a modelling term and stays in the data model, the metrics and this
> spec. It is *not* user-facing copy — the UI says "457 of 465 habits checked off", because a user
> who has to ask what a habit-day is has already been failed by the interface.

**The five logical states of a habit-day** (`HabitDayState`, derived — this is what every metric consumes):
| State | Definition |
|---|---|
| `done` | Entry exists with `.done` |
| `missed` | Entry exists with `.missed` |
| `pending` | No entry, `dateKey == today`, habit tracked on that date |
| `unlogged` | No entry, habit tracked on that date, and `startDateKey ≤ dateKey ≤ unloggedThroughDateKey`. Only arises from late-start *leaveBlank* (§7.3); rollover never touches these dates |
| `untracked` | Habit not tracked on that date (before `trackedFrom`, on/after `trackedUntil`), or `dateKey > today`, or date outside the arc |

Rollover (§7) converts every `pending` habit-day at or before yesterday into `missed`. `unlogged` habit-days are exempt and stay `unlogged` until the user backfills them (§10.1).

### 4.5 `Reflection`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `arc` | `Arc` | |
| `kind` | `ReflectionKind` | |
| `weekKey` | `WeekKey?` | Required iff `kind == .weekly`; unique per arc (FR-27) |
| `text` | `String` | ≤ 500 (weekly) / ≤ 1 000 (closing) |
| `createdAt` / `updatedAt` | `Date` | |

The closing reflection (FR-20) is the single `Reflection` row with `kind == .closing`; there is no mirror field on `Arc`. At most one closing reflection per arc.

### 4.6 `Photo`
| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | File name is `<id>.heic` |
| `arc` | `Arc` | |
| `kind` | `PhotoKind` | At most one per kind per arc; replacing deletes the old file |
| `capturedAt` | `Date` | |
| `pixelWidth` / `pixelHeight` | `Int` | For layout without decoding |

## 5. Validation Rules (`ArcDraft` → `Arc`)
Applied by `ArcSetupViewModel` per step (§3.2) and re-checked atomically in `ArcStore.createArc`.

| Rule | Error (user-facing) |
|---|---|
| `end > start` | "End date must be after start date." |
| `30 ≤ length ≤ 180` | "Arcs run between 30 and 180 days." |
| `3 ≤ pillars ≤ 5` | (Continue disabled; counter shows "n of 5") |
| pillar names unique, 1…30 chars | "You already have a pillar called …" |
| `1 ≤ habits per pillar ≤ 3` | "Add at least one habit to each pillar." / (add row hidden at 3) |
| habit names unique, 1…40 chars | "You already have a habit called …" |
| total habits > 7 | *Warning only* (FR-5) |
| `consistencyTarget` in 50…100 step 5 when ruleset is Consistency Score | (Stepper bounds) |
| `graceDayBudget` in 1…10 when ruleset is Grace Days | (Stepper bounds) |
| `whyStatement` ≤ 140 chars | (Counter; input capped) |
| No other `.active` arc | "Finish or abandon your current arc first." (should be unreachable from UI) |

## 6. Derived Metrics (`ArcMetrics`)
All functions are pure: inputs are the arc graph plus `today: DateKey` from the injected `Clock`. "Elapsed" always means `dateKey ≤ today`.

### 6.1 Habit-day state
`state(habit, d) -> HabitDayState` per §4.4.

### 6.2 Day summary
```
tracked(d)   = habits where isTracked(on: d)
doneCount(d) = |{ h ∈ tracked(d) : state(h,d) == .done }|
missedCount(d) = |{ h ∈ tracked(d) : state(h,d) == .missed }|
isDayComplete(d) = tracked(d).nonEmpty && doneCount(d) == tracked(d).count
unloggedCount(d) = |{ h ∈ tracked(d) : state(h,d) == .unlogged }|
heatLevel(d) = tracked(d).isEmpty || d > today ? nil
             : unloggedCount(d) == tracked(d).count ? .unlogged      // distinct case, rendered hatched
             : doneCount(d) == 0 ? 0
             : ratio < 1/3 ? 1 : ratio < 2/3 ? 2 : ratio < 1 ? 3 : 4   where ratio = doneCount / tracked.count
hasGraceDay(d) = ruleset == .graceDays && missedCount(d) > 0
```
`isDayComplete(today)` drives the day-complete banner (§3.3). `heatLevel` drives `HeatMapView` (FR-15); `nil` renders as an outlined future/untracked cell; `.unlogged` renders as a hatched cell so a backfill gap is never mistaken for a fully-missed day.

### 6.3 Current streak (FR-12)
```
currentStreak(habit, today):
  n = 0; d = today
  while d ≥ habit.trackedFromDateKey && d ≥ arc.startDateKey:
    switch state(habit, d):
      case .done:      n += 1
      case .missed:    return n
      case .pending, .unlogged, .untracked:  (skip — neither extends nor breaks)
    d = d − 1 day
  return n
```
Consequences: today's pending habit does not break yesterday's streak; a backfill gap (`unlogged`) is transparent until it is filled; marking a past day `missed` via edit breaks the streak retroactively.

### 6.4 Best streak (FR-12)
Forward scan from `trackedFromDateKey` to `min(today, trackedUntil − 1, endDateKey)` with the same skip/break rules; `bestStreak = max` run length observed, including the current run.

### 6.5 Consistency Score (FR-13)
```
scoreNumerator   = |{ (h,d) : d ≤ today, state(h,d) == .done }|
scoreDenominator = |{ (h,d) : d ≤ today, state(h,d) ∈ {.done, .missed} }|
consistencyScore = scoreDenominator == 0 ? nil : scoreNumerator / scoreDenominator     // 0.0…1.0
```
- `pending` (today, not yet toggled) and `unlogged` habit-days are **excluded** from the denominator. The score therefore never drops just because it is morning; it drops at rollover when pending becomes missed.
- `nil` renders as "—" (Day 1 before the first toggle; §3.5 day-0 state).
- Under the Consistency Score ruleset, `targetMet = consistencyScore ≥ consistencyTarget / 100`, evaluated for the completion screen only (§3.9); it is never a failure condition mid-arc.

### 6.6 Per-pillar and per-habit completion (FR-14)
Same formula as §6.5 restricted to the pillar's habits / the single habit.

### 6.7 Grace days (FR-17)
```
graceDaysUsed   = |{ d : d ≤ today, hasGraceDay(d) }|        // distinct dates with ≥1 missed habit
graceDaysLeft   = max(0, graceDayBudget − graceDaysUsed)
isGraceExhausted = graceDaysUsed > graceDayBudget
```
- A day consumes **one** grace day regardless of how many habits were missed on it.
- **Budget `N` means `N` missed dates are forgiven; the `(N+1)`th missed date fails the arc.** All user-facing copy must say this ("3 forgiven misses — one more and the arc is failed"), never "using the last grace day fails".
- Editing a past day so it no longer has misses **refunds** the grace day automatically (it is derived, nothing to undo). Editing a done habit to missed on a day that had no misses consumes one and may set `isGraceExhausted` — the UI warns first (§3.4).
- `hasGraceDay` for late-start `markAllMissed` days counts normally (the UI warns at setup, §3.2.7). If that alone exceeds the budget, the arc is failed immediately after creation and `GraceDaysExhaustedView` is presented.
- **Reversibility.** `ArcStore.setEntry` re-evaluates after every write: if `status == .failed && failureResolution == nil` (the user has not yet answered the exhaustion screen) and the write brings `isGraceExhausted` back to `false`, the arc returns to `status = .active`, `endedAt = nil`. Once `failureResolution` is set, the arc stays `.failed` regardless of later edits.

### 6.8 Day index and countdown (FR-9)
```
totalDays  = daysBetween(start, end) + 1
dayIndex   = clamp(daysBetween(start, today) + 1, 0, totalDays)   // 0 ⇒ not started
daysLeft   = max(0, daysBetween(today, end))                       // 0 on the final day
```

### 6.9 Arc phase (derived from `status` + dates)
| Phase | Condition | UI |
|---|---|---|
| `notStarted` | `status == .active && today < start` | Today countdown (§3.3) |
| `running` | `status == .active && start ≤ today ≤ end` | Normal |
| `awaitingCompletion` | `status == .active && today > end` | Present `ArcCompleteView` (§3.9) until the user finishes the flow, which sets `status = .completed` |
| `failedUnresolved` | `status == .failed && failureResolution == nil` | Present `GraceDaysExhaustedView` (§3.10) as a cover over the tabs on every launch/foreground until the user chooses; the arc is still *current* |
| `failedRunning` | `status == .failed && failureResolution == .keepGoing && today ≤ end` | Today usable, status strip "Failed · tracking continues" |
| `failedAwaitingCompletion` | `status == .failed && failureResolution == .keepGoing && today > end` | `ArcCompleteView` variant; ends as `.failed` and the arc stops being current once the flow completes (`failureResolution` stays `.keepGoing`; `endedAt` set) |
| `archived` | `status ∈ {completed, abandoned}`, or `status == .failed && failureResolution == .restarted`, or a `failedAwaitingCompletion` arc whose completion flow has finished | Read-only (FR-21) |

## 7. Day Rollover (`DayRolloverService`, FR-11, NFR-5)

### 7.1 When
On app launch and on every `scenePhase == .active`, **before** any view reads today's data. Also immediately after `ArcStore.createArc`. Never in the background.

### 7.2 Algorithm
```
finalizeIfNeeded(arc, today):
  guard arc.isCurrent else return
  from = arc.rolloverCursorDateKey.map { $0 + 1 } ?? arc.startDateKey
  to   = min(today − 1, arc.endDateKey)
  guard from ≤ to else return                       // nothing to do (idempotent)
  for d in from…to:
    if let u = arc.unloggedThroughDateKey, d ≤ u: continue     // late-start blank days stay unlogged
    for h in habits where h.isTracked(on: d) && entry(h, d) == nil:
      upsert DailyEntry(h, d, .missed, source: .rollover)
  arc.rolloverCursorDateKey = to
  applyRulesetEffects(arc, today)
  writeWidgetSnapshot()
```
`applyRulesetEffects`: if `ruleset == .graceDays && isGraceExhausted && status == .active` → `status = .failed`, `endedAt = now`, `failureResolution = nil`; the phase becomes `failedUnresolved` and the UI presents `GraceDaysExhaustedView` on this foreground. The reminder is not touched by rollover; it changes only on arc-status transitions (§11, frontend §8).

### 7.3 Late start (FR-22, §3.2.7)
At `createArc` when `start < today`:
| Choice | Entries created | `rolloverCursorDateKey` | `unloggedThroughDateKey` |
|---|---|---|---|
| `markAllDone` | `.done`, `source: .lateStart`, for every `(h, d)`, `d ∈ [start, today−1]` | `today − 1` | nil |
| `markAllMissed` | `.missed`, same range | `today − 1` | nil |
| `leaveBlank` | none | `today − 1` | `today − 1` — those dates read as `unlogged` (§4.4) until backfilled |

Then `finalizeIfNeeded` runs (a no-op in all three cases), followed by `applyRulesetEffects` — so `markAllMissed` can fail a Grace Days arc immediately (§6.7).

### 7.4 Time zones, DST, and clock changes
- `today` is computed from `Clock.now` with the Gregorian calendar and the injected time zone (the device's at that instant). DST transitions do not affect `DateKey` arithmetic because it is done in calendar days, not seconds.
- Travelling east/west may make "today" repeat or skip a `DateKey`. Repeat ⇒ `from > to` ⇒ no-op. Skip ⇒ the skipped date is finalised normally on the next foreground.
- **Clock rolled backwards** (`today < rolloverCursorDateKey`): do nothing, keep all entries, surface the warning caption (§9 of frontend spec). Entries dated in the "future" remain and become visible again when the clock catches up.
- Rollover never modifies an existing entry, so re-running on the same `today` is a no-op.

## 8. Widget Snapshot (FR-25)
Written by the app after **every** persistence change and by rollover; read by the widget extension (no SwiftData in the widget for simplicity and launch speed).
```json
{
  "schema": 1,
  "hasActiveArc": true,
  "dateKey": "2026-11-03",
  "dayIndex": 34, "totalDays": 92, "daysLeft": 58,
  "doneCount": 3, "habitCount": 5,
  "consistencyScore": 0.87,
  "habits": [ { "name": "Gym", "isDone": true }, … ]      // active habits, sortOrder, ≤ 7
}
```
The file is written with `Data.write(options: .atomic)`. The widget reads **only** this JSON — it never opens the SwiftData store. If the file is missing, unreadable, or its `schema` is unknown, the widget renders the "Start your Winter Arc" state and the app rewrites the snapshot on next launch. The widget timeline has two entries: now, and local midnight (`dateKey + 1`, `doneCount: 0`). `WidgetCenter.shared.reloadTimelines(ofKind: "TodayWidget")` is called after each write.

## 9. `UserDefaults` (App Group suite)
| Key | Type | Default | Purpose |
|---|---|---|---|
| `schemaVersion` | `Int` | 1 | Migration gate (§10) |
| `hasSeenWelcome` | `Bool` | false | §3.1 |
| `editWindowDays` | `Int` | 7 | NFR-6; `0` ⇒ unlimited |
| `missCardDismissedDateKey` | `String?` | nil | FR-18 — card hidden for the rest of that date |
| `lastMissCardShownDateKey` | `String?` | nil | FR-18 — never shown more than once per date |

## 10. Edit Window (NFR-6, FR-16)
```
canEdit(d, today):
  if d > today: false
  if state has no entry and d is unlogged: true            // backfill is always allowed
  if editWindowDays == 0: true
  return daysBetween(d, today) ≤ editWindowDays
```
Editing a `missed`/`done` entry outside the window is refused in the UI (checkboxes disabled). Backfilling an `unlogged` habit-day is always permitted so late joiners are not locked out (UJ6). The exemption is **per habit-day**: filling in one habit must not lock the others on that date. `DayDetailSheet` evaluates the rule per row; its read-only caption uses a day-level roll-up (`canEdit(date:in:)`, true while *any* habit on the date is still editable).

### 10.1 Edit transitions (`ArcStore.setEntry` / `clearEntry`)
The control shown in `DayDetailSheet` and the transitions it performs depend on the habit-day state:

| Date | States possible | Control | Tap behaviour |
|---|---|---|---|
| Today | `pending` ⇄ `done` | Checkbox | done → `setEntry(.done)`; undo → `clearEntry` (row deleted, back to `pending`). `missed` is never written for today by the user |
| Past, finalised (`d ≤ rolloverCursorDateKey`) | `done` ⇄ `missed` | Checkbox | Toggles between `.done` and `.missed` via `setEntry`; an entry is never deleted, so the day can never become `pending` |
| Past, unlogged (`d ≤ unloggedThroughDateKey`, no entry) | `unlogged` → `done` \| `missed` | Tri-state segmented control (Done / Missed / — ) | First selection creates the entry; thereafter behaves as a finalised day (done ⇄ missed). Choosing "—" again is not offered once an entry exists |
| Future, or habit untracked on `d` | `untracked` | None (row hidden) | — |

After every write the store recomputes grace usage and applies the reversibility rule (§6.7) and exhaustion rule (§7.2 `applyRulesetEffects`).

## 11. Restart, Abandon, Delete (FR-24, FR-28)
- **Restart** is atomic. `ArcStore.restartDraft(from: arc)` builds an `ArcDraft` from the *still-current* arc, copying pillars (name, symbol, presetKey, order), active habits (name, order), ruleset + config, `whyStatement`, reminder time; `start = today`, `end = today + (oldLength − 1)`. Photos, reflections, and entries are **not** copied. Nothing is persisted at this point. The draft goes through the normal setup flow and validation; **cancelling leaves the old arc exactly as it was.** On **Start Arc**, `ArcStore.restart(from: old, draft:)` performs one save that (a) sets the old arc's status — `.completed` when reached from the completion flow, `.abandoned` from Settings, or for a `.failed` arc sets `failureResolution = .restarted` — with `endedAt = now`, and (b) inserts the new `.active` arc. The uniqueness invariant (§4.1) holds before and after; if the app terminates mid-setup the old arc is still current on next launch.
- **Abandon:** `status = .abandoned`, `endedAt = now`, cancel reminder, write widget snapshot (`hasActiveArc: false`). Abandoning a `.failed` keep-going arc simply sets `status = .abandoned`; it stops being current.
- **Delete permanently:** delete the `Arc` (cascades), delete its photo files, then the same cleanup as abandon.
- **Keep going** (FR-31): `failureResolution = .keepGoing`; nothing else changes. The reminder stays scheduled.

## 12. Schema Versioning & Migration
- `schemaVersion = 1` for the App Store launch. SwiftData `VersionedSchema` is declared from day one (`WinterArcSchemaV1`) so future changes use a `SchemaMigrationPlan` rather than a store reset.
- Additive changes (new optional fields) are lightweight migrations. Anything else requires a custom stage and a unit test that opens a V1 fixture store.
- The widget snapshot and `UserDefaults` carry their own `schema` integers and are simply rewritten if stale.

## 13. Worked Examples (reference for `test-spec.md`)
Arc Oct 1 – Dec 31 (92 days), habits **Gym** and **Read**, today = Oct 6, ruleset Grace Days (budget 3).

| Date | Gym | Read | Notes |
|---|---|---|---|
| Oct 1 | done | done | |
| Oct 2 | done | missed | grace day 1 |
| Oct 3 | done | done | |
| Oct 4 | missed | missed | grace day 2 (one per date) |
| Oct 5 | done | done | |
| Oct 6 (today) | done | pending | |

- `currentStreak(Gym) = 2` (Oct 5, 6; Oct 4 breaks). `bestStreak(Gym) = 3` (Oct 1–3).
- `currentStreak(Read) = 1` (Oct 5; today pending is skipped; Oct 4 breaks). `bestStreak(Read) = 1`.
- `consistencyScore = 8 / 11 ≈ 0.727` (11 = all done+missed; Read on Oct 6 is pending, excluded).
- `graceDaysUsed = 2`, `graceDaysLeft = 1`, not exhausted.
- `heatLevel(Oct 4) = 0`, `heatLevel(Oct 2) = 2` (1 of 2 = 0.5 → level 2), `heatLevel(Oct 6) = 2` so far.
- If the user edits Oct 2 Read → done: score `9 / 11`, `graceDaysUsed = 1`, `bestStreak(Read) = 3`.
- If rollover runs with today = Oct 7 and Read still pending on Oct 6: Read Oct 6 → missed, `graceDaysUsed = 3`, `currentStreak(Read) = 0`. Budget 3 is now fully used but **not** exceeded. One more missed date → `graceDaysUsed = 4 > 3` → exhausted → `status = .failed`, phase `failedUnresolved`.
- Per-habit completion at Oct 6: Gym `5/6`, Read `3/5` (Oct 6 pending excluded).

## 14. Resolved Decisions
- Closing reflection is a `Reflection` row only; no mirror on `Arc` (§4.5).
- The widget reads the JSON snapshot only, never SwiftData (§8).
- Grace Days: budget `N` forgives `N` missed dates; the `(N+1)`th fails (§6.7).
- A failure can be reversed by a refunding edit only while unresolved (§6.7).
- Restart is atomic on Start Arc; cancelling is a no-op (§11).

---
**Status:** Draft v2 · **Owner:** Vipin Pahwa · **Last updated:** 2026-09-21
