# Test Spec — Winter Arc iOS App

> Purpose: enumerate every automated test case and the manual QA checklist. Each case cites the requirement (FR-x / NFR-x from `goal-spec.md`) and the definition it verifies (§x.y of `data-spec.md` or `frontend-spec.md`). A requirement with no test here is not considered done.
> Scope for v1: **unit tests only** (Swift Testing). UI tests are deferred; journeys are covered by the manual checklist in §20.

## 1. Conventions
- **Framework:** Swift Testing (`@Suite`, `@Test`, `#expect`, `#require`). One suite per section below; file name matches the suite.
- **Target:** `WinterArcTests`, depends on the app module with `@testable import`.
- **Persistence:** every suite that touches SwiftData uses an **in-memory** `ModelContainer` built from `WinterArcSchemaV1`, created fresh per test.
- **Time:** all code under test receives a `Clock` protocol; tests use `FixedClock(now:)` or `MutableClock` for rollover sequences. No test reads the wall clock. The calendar is always an explicit `Calendar(identifier: .gregorian)` with an injected `TimeZone`; default fixture is `America/New_York` to exercise DST. Week keys use `Calendar(identifier: .iso8601)`.
- **Fixtures (`TestFixtures.swift`):**
  - `makeArc(start:end:ruleset:target:budget:habits:)` — builds an arc with pillar "P1" and named habits, all `trackedFrom = start`.
  - `log(_ arc, _ habit, _ dateKey, _ state)` — upserts an entry with `source: .user`.
  - `classicArc()` — Oct 1 – Dec 31, 2026, habits Gym + Read, Grace Days budget 3 (the §13 worked example in `data-spec.md`).
  - `SpyNotificationScheduler`, `SpyWidgetRefresher`, `SpyPhotoStore` — record calls for assertion.
- **Naming:** `test_<behaviour>_<condition>()`. IDs below (e.g. `STK-03`) appear in the test's display name so failures map back to this document.
- **Determinism:** no `Date()`, `Calendar.current`, `Calendar.autoupdatingCurrent`, `TimeZone.current`, or `TimeZone.autoupdatingCurrent` in the app module outside the production `SystemClock`. A lint test (`CONV-01`) greps the source for these and fails if found outside that file.

## 2. DateKey (`DateKeyTests`) — data-spec §2
| ID | Case | Expected | Traces |
|---|---|---|---|
| DK-01 | `today` from a fixed instant in `America/New_York` (Gregorian calendar injected) | `"2026-10-01"` for 2026-10-01 23:30 local; `"2026-10-02"` for 00:30 local | NFR-5 |
| DK-01b | Same instant with a Japanese-identifier calendar passed by mistake | `DateKey.today` ignores it and still yields `"2026-10-01"` (the helper constructs its own Gregorian calendar from the time zone) | NFR-5 |
| DK-02 | Same instant, different time zones | Instant 2026-10-02 03:00 UTC ⇒ `"2026-10-01"` in New York, `"2026-10-02"` in Tokyo | NFR-5 |
| DK-03 | `adding(days:)` across a month and year boundary | `"2026-12-31" + 1 = "2027-01-01"`; `"2026-03-01" − 1 = "2026-02-28"` | §2 |
| DK-04 | `adding(days:)` across DST forward (Mar 8 2026) and back (Nov 1 2026) | Day count unaffected; `"2026-11-01" + 1 = "2026-11-02"` | NFR-5 |
| DK-05 | `daysBetween` | `("2026-10-01","2026-12-31") = 91`; same day = 0; reversed = −91 | FR-1 |
| DK-06 | Lexicographic order equals chronological | Sorted array of shuffled keys equals chronological order | §2 |
| DK-07 | Invalid strings rejected | `"2026-1-1"`, `"2026-13-01"`, `""` ⇒ init returns nil | §2 |
| DK-08 | `weekKey` ISO week-based year | `"2026-01-01"` ⇒ `"2026-W01"`; `"2026-12-31"` ⇒ `"2026-W53"`; **`"2024-12-31"` ⇒ `"2025-W01"`; `"2027-01-01"` ⇒ `"2026-W53"`** (the last two fail with a `yyyy` format) | FR-27 |

## 3. Draft Validation (`ArcDraftValidationTests`) — data-spec §5, FR-1–FR-8
| ID | Case | Expected | Traces |
|---|---|---|---|
| VAL-01 | Default draft on Sep 1 | start Oct 1, end Dec 31 of that year | FR-2 |
| VAL-02 | Default draft on Nov 15 (inside window, ≥ 30 days left) | start Nov 15, end Dec 31 | FR-2 |
| VAL-03 | Default draft on Dec 15 (< 30 days left) | start Dec 15, end Mar 14 (90 days) | FR-2 |
| VAL-04 | End before/equal start | error `.endNotAfterStart` | FR-2 |
| VAL-05 | Length 29 and 181 | error `.lengthOutOfRange`; 30 and 180 pass | FR-2 |
| VAL-06 | 2 pillars / 6 pillars | invalid; 3 and 5 valid | FR-3 |
| VAL-07 | Duplicate pillar name, case-insensitive ("Gym"/"gym") | error `.duplicatePillar` | FR-3 |
| VAL-08 | Pillar name 0 or 31 chars | invalid; 1 and 30 valid | FR-3 |
| VAL-09 | 0 habits in a pillar / 4 habits | invalid; 1 and 3 valid | FR-4 |
| VAL-10 | Duplicate habit name across pillars | error `.duplicateHabit` | FR-4 |
| VAL-11 | Total habits 8 | `warnings` contains `.tooManyHabits`; `isValid == true` | FR-5 |
| VAL-12 | Consistency Score target 45 / 105 / 87 | invalid; 50, 85, 100 valid | FR-6 |
| VAL-13 | Grace Days budget 0 / 11 | invalid; 1 and 10 valid | FR-6 |
| VAL-14 | Ruleset Streaks with a target set | target ignored, stored as nil | FR-6 |
| VAL-15 | Why statement 141 chars / whitespace only | truncated to 140 / stored nil | FR-7 |
| VAL-16 | Reminder off | `reminderHour/Minute == nil` | FR-8 |
| VAL-17 | `createArc` while an active arc exists | throws `.activeArcExists`; store unchanged | §4.1 |

## 4. Habit-Day State (`HabitDayStateTests`) — data-spec §4.4
| ID | Case | Expected | Traces |
|---|---|---|---|
| HDS-01 | Entry `.done` | `.done` | §4.4 |
| HDS-02 | Entry `.missed` | `.missed` | §4.4 |
| HDS-03 | No entry, date == today, tracked | `.pending` | §4.4 |
| HDS-04 | No entry, tracked, `start ≤ date ≤ unloggedThroughDateKey` | `.unlogged` | §4.4, FR-22 |
| HDS-04b | No entry, date < today, tracked, `unloggedThroughDateKey == nil`, date ≤ rollover cursor | impossible after rollover; if constructed directly the state resolves to `.pending`-equivalent and rollover fixes it — test asserts rollover produces `.missed` | §7.2 |
| HDS-05 | No entry, date > today | `.untracked` | §4.4 |
| HDS-06 | Date before `trackedFromDateKey` (habit added mid-arc) | `.untracked` | FR-23 |
| HDS-07 | Date on/after `trackedUntilDateKey` (soft-deleted) | `.untracked`; entries before it still `.done`/`.missed` | FR-23 |
| HDS-08 | Date outside arc range | `.untracked` | §4.4 |

## 5. Streaks (`StreakTests`) — data-spec §6.3, §6.4, FR-12
| ID | Case | Expected | Traces |
|---|---|---|---|
| STK-01 | Done Oct 1–3, today Oct 3 | current 3, best 3 | FR-12 |
| STK-02 | Done Oct 1–3, missed Oct 4, today Oct 4 | current 0, best 3 | FR-12 |
| STK-03 | Done Oct 1–3, missed Oct 4, done Oct 5–6, today Oct 6 | current 2, best 3 | §13 |
| STK-04 | Today pending, yesterday done ×3 | current 3 (pending skipped) | §6.3 |
| STK-05 | Unlogged gap: done Oct 1–2, Oct 3–4 unlogged, done Oct 5, today Oct 5 | current 3 (gap transparent) | §6.3, UJ6 |
| STK-06 | Backfill the gap in STK-05 as missed on Oct 3 | current 1, best 2 | FR-16 |
| STK-07 | Habit added Oct 10 (`trackedFrom`), done Oct 10–12 | current 3; Oct 1–9 do not break | FR-23 |
| STK-08 | Soft-deleted Oct 20 after done Oct 1–19, today Oct 25 | best 19; habit excluded from Today | FR-23 |
| STK-09 | No entries at all | current 0, best 0 | FR-12 |
| STK-10 | Streak spanning DST-back (Oct 31 – Nov 2, New York) | current 3 | NFR-5 |
| STK-11 | Best streak in the middle, not current: done 1–5, missed 6, done 7–8, today 8 | current 2, best 5 | §6.4 |

## 6. Consistency Score (`ConsistencyScoreTests`) — data-spec §6.5, §6.6, FR-13, FR-14
| ID | Case | Expected | Traces |
|---|---|---|---|
| CS-01 | No entries, Day 1 | `nil` | §6.5 |
| CS-02 | §13 worked example (today Oct 6, Read pending) | `8/11` | §13 |
| CS-03 | Edit Oct 2 Read → done | `9/11` | FR-16 |
| CS-04 | Pending today excluded | Day 5, all done days 1–4, nothing today ⇒ `1.0` | §6.5 |
| CS-05 | After rollover to Oct 7 in CS-02 | `8/12` | FR-11 |
| CS-06 | Unlogged days excluded | late start, leaveBlank, 5 days, log only today done ⇒ `1.0` | FR-22 |
| CS-07 | Per-pillar with two pillars | pillar A `1.0`, pillar B `0.5`, arc `0.75` (equal habit counts) | FR-14 |
| CS-08 | Per-habit | Gym `5/6`, Read `3/5` in the §13 example (Read on Oct 6 pending, excluded) | FR-12 |
| CS-09 | `targetMet` at exactly the target | score `0.85`, target 85 ⇒ true; `0.849` ⇒ false | FR-6, §3.9 |
| CS-10 | Soft-deleted habit's past entries still count | denominator unchanged after delete | FR-23 |

## 7. Grace Days (`GraceDayTests`) — data-spec §6.7, FR-17
| ID | Case | Expected | Traces |
|---|---|---|---|
| GD-01 | §13 example | used 2, left 1, not exhausted | §13 |
| GD-02 | Two habits missed on one date | used 1 | §6.7 |
| GD-03 | Budget 3, four distinct missed dates | `isGraceExhausted == true` | FR-17 |
| GD-04 | Budget 3, exactly three missed dates | not exhausted, left 0 | FR-17 |
| GD-05 | Refund: fix the only miss on a date | used decreases by 1 | §6.7 |
| GD-06 | Ruleset Streaks | `graceDaysUsed` not computed / `hasGraceDay` always false | §6.2 |
| GD-07 | Late start `markAllMissed` with 5 elapsed days, budget 3 | used 5, exhausted | FR-22 |
| GD-08 | Exhaustion via rollover sets `status = .failed`, `endedAt` set | after `finalizeIfNeeded` | FR-17, §7.2 |
| GD-09 | Exhaustion via past-day edit | metrics report exhausted; `ArcStore.setEntry` transitions status | §3.4 |
| GD-10 | `failureResolution = .keepGoing` | rollover keeps creating entries after failure; arc remains current | §3.10, §6.9 |
| GD-11 | Failed & unresolved (`failureResolution == nil`); edit refunds a grace day so `used ≤ budget` | status returns to `.active`, `endedAt == nil` | §6.7 |
| GD-12 | Failed & `.keepGoing`; same refund | status stays `.failed` | §6.7 |
| GD-13 | Late start `markAllMissed` with 4 elapsed days, budget 3 | arc is `.failed` immediately after `createArc`; phase `failedUnresolved` | §7.3, FR-22 |

## 8. Day Summary & Heat-map (`DaySummaryTests`) — data-spec §6.2, FR-9, FR-15
| ID | Case | Expected | Traces |
|---|---|---|---|
| DS-01 | 5 habits, 0 done | level 0 | FR-15 |
| DS-02 | 5 habits, 1 / 2 / 3 / 4 / 5 done | levels 1 / 2 / 2 / 3 / 4 | §6.2 |
| DS-03 | 2 habits, 1 done | level 2 (0.5) | §13 |
| DS-04 | Future date | `nil` | FR-15 |
| DS-05 | Date with zero tracked habits (all added later) | `nil` | FR-23 |
| DS-06 | `isDayComplete` | true only when all tracked done; false with zero tracked | §3.3 |
| DS-07 | `hasGraceDay` under Grace Days with ≥1 missed | true; false under other rulesets | §3.5 |
| DS-08 | All tracked habits `unlogged` on a date | `heatLevel == .unlogged`, distinct from `0` | §6.2 |
| DS-09 | One habit backfilled done, one still unlogged | numeric level from the done ratio (unlogged treated as not done for the ratio), not `.unlogged` | §6.2 |

## 9. Day Index & Phase (`ArcPhaseTests`) — data-spec §6.8, §6.9, FR-9
| ID | Case | Expected | Traces |
|---|---|---|---|
| PH-01 | today = start | dayIndex 1, daysLeft 91, `.running` | FR-9 |
| PH-02 | today = end | dayIndex 92, daysLeft 0, `.running` | FR-9 |
| PH-03 | today = start − 3 | dayIndex 0, `.notStarted` | §3.3 |
| PH-04 | today = end + 1, active | `.awaitingCompletion` | §3.9 |
| PH-05 | status completed | `.archived` regardless of date | FR-21 |
| PH-06 | failed, `.keepGoing`, today ≤ end | `.failedRunning` | §3.10 |
| PH-07 | failed, `.keepGoing`, today > end | `.failedAwaitingCompletion` | §6.9 |
| PH-08 | failed, `.restarted` | `.archived`; `isCurrent == false` | §6.9 |
| PH-09 | failed, `failureResolution == nil` | `.failedUnresolved`; `isCurrent == true`; `ArcStore.currentArc` returns it | §6.9, FR-31 |
| PH-10 | Relaunch (new store instance over same data) after keep-going | `currentArc` is the failed arc; phase `.failedRunning` | FR-31 |

## 10. Day Rollover (`DayRolloverTests`) — data-spec §7, FR-11, NFR-5
| ID | Case | Expected | Traces |
|---|---|---|---|
| RO-01 | Fresh arc, today = start | no entries created, `rolloverCursorDateKey == nil` | §7.2 |
| RO-02 | today = start + 1, nothing logged on start | one `.missed` per habit for start, `source: .rollover`, `rolloverCursorDateKey = start` | FR-11 |
| RO-03 | Run twice with the same `today` | second run creates nothing (idempotent) | NFR-5 |
| RO-04 | App unused for 5 days | 5 dates finalised in one call | §7.2 |
| RO-05 | Existing `.done` entries are untouched | rollover never overwrites | §7.4 |
| RO-06 | today > end | finalises through `end` only; `rolloverCursorDateKey = end` | §7.2 |
| RO-07 | Habit added mid-arc | not back-filled as missed before `trackedFrom` | FR-23 |
| RO-08 | Soft-deleted habit | no entries created on/after `trackedUntil` | FR-23 |
| RO-09 | Late start `leaveBlank` (start = today − 4) | `rolloverCursorDateKey = today − 1`, `unloggedThroughDateKey = today − 1`; zero entries; the 4 days are `.unlogged`; a later rollover (today + 1) still creates no entries for them | FR-22, §7.3 |
| RO-10 | Late start `markAllDone` | `.done` entries `source: .lateStart` for all 4 days × habits | FR-22 |
| RO-11 | Late start `markAllMissed` | `.missed` entries; grace usage 4 | FR-22 |
| RO-12 | DST forward: `MutableClock` Mar 7 → Mar 8 → Mar 9 (New York) | exactly one date finalised per step | NFR-5 |
| RO-13 | DST back: Oct 31 → Nov 1 → Nov 2 | same | NFR-5 |
| RO-14 | Travel west: today repeats (`from > to`) | no-op | §7.4 |
| RO-15 | Travel east: a date is skipped | skipped date finalised on next run | §7.4 |
| RO-16 | Clock rolled back (`today < rolloverCursorDateKey`) | no changes; `needsClockWarning == true` | §7.4 |
| RO-17 | Arc `.abandoned` / `.completed` | rollover is a guard-return | §7.2 |
| RO-18 | Rollover on failed arc with `.restarted` | no-op | §7.2 |
| RO-18b | Rollover on failed & unresolved arc | runs (arc is current); status stays `.failed` | §7.2 |
| RO-19 | Widget snapshot written after rollover; reminder **not** touched | snapshot spy called once; notification spy not called | FR-25, FR-8 |

## 11. Entry Writes (`ArcStoreEntryTests`) — FR-10, FR-16, NFR-5
| ID | Case | Expected | Traces |
|---|---|---|---|
| EW-01 | `setEntry` on a new (habit, date) | one row inserted, `source: .user` | FR-10 |
| EW-02 | `setEntry` twice on the same (habit, date) | one row, state updated, `updatedAt` advanced | §4.4 |
| EW-03 | Toggle done → clear on today | row removed (returns to `.pending`) | §3.3 |
| EW-04 | Write for a date outside the arc / untracked habit | throws `.invalidDate` | §4.4 |
| EW-05 | Write is visible on immediate re-fetch | no async gap (synchronous save) | NFR-5 |
| EW-06 | Snapshot + widget reload after each write | spy called | FR-25 |
| EW-07 | Soft-delete a habit that has a `.done` entry for today | `trackedUntilDateKey == today + 1`; today's entry still `.done` and still tracked | FR-23, §4.3 |
| EW-07b | Soft-delete a habit with no entry today | `trackedUntilDateKey == today` | §4.3 |
| EW-08 | Toggle a finalised past `.done` entry | becomes `.missed`, never deleted; toggling again → `.done` | §10.1 |
| EW-09 | Backfill an `unlogged` day as `.missed` | entry created; date no longer `.unlogged`; grace usage updated | §10.1 |

## 12. Edit Window (`EditWindowTests`) — data-spec §10, NFR-6
| ID | Case | Expected | Traces |
|---|---|---|---|
| EWN-01 | Future date | `canEdit == false` | NFR-6 |
| EWN-02 | Logged day 7 days ago, window 7 | true; 8 days ago false | NFR-6 |
| EWN-03 | Window 0 (unlimited), 100 days ago | true | NFR-6 |
| EWN-04 | Unlogged day 30 days ago, window 7 | true (backfill always allowed) | UJ6 |
| EWN-05 | Today | true | FR-10 |

## 13. Restart / Abandon / Delete (`ArcLifecycleTests`) — data-spec §11, FR-24, FR-28
| ID | Case | Expected | Traces |
|---|---|---|---|
| LC-01 | `restartDraft(from:)` | copies pillars (name, symbol, presetKey, order), active habits only, ruleset + config, why, reminder; `start = today`, `end = today + length − 1` | FR-28 |
| LC-02 | Restart excludes soft-deleted habits, photos, reflections, entries | draft has none | FR-28 |
| LC-03 | Restart archives the old arc with the given status and `endedAt` | `.abandoned` from Settings, `.failed` from exhaustion, `.completed` from finish | FR-28 |
| LC-04 | After restart, exactly one active arc | count == 1 | §4.1 |
| LC-05 | Abandon | status `.abandoned`, reminder cancelled (spy), snapshot `hasActiveArc: false` | FR-24 |
| LC-06 | Delete permanently | arc and all children gone; photo files deleted (spy) | FR-24 |
| LC-07 | Complete flow | status `.completed`, closing reflection stored | FR-19, FR-20 |
| LC-08 | Archived arcs list | sorted by `endedAt` desc; includes final score and status | FR-21 |
| LC-09 | Build a restart draft, then discard it | old arc unchanged: still `.active`, no `endedAt`, still `currentArc` | FR-28, §11 |
| LC-10 | `restart(from:draft:)` | single save: old arc status/`failureResolution` set + `endedAt`; new arc `.active`; exactly one current arc before and after; a thrown validation error leaves both untouched | FR-28, §11 |
| LC-11 | Keep going | `failureResolution == .keepGoing`; reminder spy not called; snapshot rewritten | FR-31 |

## 14. Ruleset Switch (`RulesetSwitchTests`) — §3.8.2, FR-6
| ID | Case | Expected | Traces |
|---|---|---|---|
| RS-01 | Streaks → Grace Days with 2 past missed dates, budget 3 | `previewGraceDaysUsed == 2`; status stays active | §3.8.2 |
| RS-02 | Streaks → Grace Days with 4 past missed dates, budget 3 | preview reports exhausted; applying sets `.failed` | §3.8.2 |
| RS-03 | Grace Days → Streaks after failure (any resolution) | status remains `.failed` (ruleset change never un-fails) | §6.9, FR-29 |
| RS-04 | Any → Consistency Score | target defaults to 85 if nil | FR-6 |

## 15. Reflections (`ReflectionTests`) — FR-20, FR-27
| ID | Case | Expected | Traces |
|---|---|---|---|
| RF-01 | Save weekly for `2026-W41` twice | one row, text overwritten | FR-27 |
| RF-02 | Weekly text 501 chars | rejected / truncated to 500 | §4.5 |
| RF-03 | Closing reflection 1 001 chars | truncated to 1 000 | FR-20 |
| RF-04 | `shouldPromptWeekly(today)` | false before Day 7; true on/after Day 7 when no reflection for the current week | §3.5 |

## 16. Photos (`PhotoStoreTests`) — FR-26, NFR-4
| ID | Case | Expected | Traces |
|---|---|---|---|
| PHO-01 | Store a 4 000 × 3 000 image | file exists at `<id>.heic`, longest edge 1 600, dims recorded | FR-26 |
| PHO-02 | Replace `before` photo | old file deleted, new row | §4.6 |
| PHO-03 | Delete arc | files removed | FR-24 |
| PHO-04 | Path is inside the App Group container, not the photo library | prefix check | NFR-4 |

## 17. Widget Snapshot (`WidgetSnapshotTests`) — data-spec §8, FR-25
| ID | Case | Expected | Traces |
|---|---|---|---|
| WS-01 | Encode §13 example, today Oct 6 | `dayIndex 6, totalDays 92, daysLeft 86, doneCount 1, habitCount 2, habits[Gym].isDone true` | FR-25 |
| WS-02 | No active arc | `hasActiveArc false`, other fields absent/zero | §3.11 |
| WS-03 | More than 7 habits | truncated to 7 by sortOrder | §8 |
| WS-04 | Midnight timeline entry | `dateKey + 1`, `doneCount 0`, `dayIndex + 1` | §8 |
| WS-05 | Round-trip decode | equal | §8 |
| WS-06 | Corrupt / missing / unknown-schema snapshot | widget model decodes to the "no active arc" state without throwing | §8 |
| WS-07 | Write is atomic | file written via `.atomic`; a simulated failure mid-write leaves the previous file intact | §3 |

## 18. Reminder (`ReminderSchedulerTests`) — frontend-spec §8, FR-8
| ID | Case | Expected | Traces |
|---|---|---|---|
| RM-01 | Schedule with 20:00 | one request, id `daily-reminder`, `UNCalendarNotificationTrigger` hour 20 minute 0, `repeats == true` | FR-8 |
| RM-02 | Content | title "Winter Arc", body "Time to check in on today's non-negotiables."; identical regardless of arc state | FR-8 |
| RM-03 | Toggle off | pending request removed | FR-8 |
| RM-04 | Abandon / delete / complete / restart-archive | request removed (spy) | FR-8 |
| RM-05 | Change time to 07:30 | old request replaced; still exactly one pending | FR-8 |
| RM-06 | Entry toggle / rollover | scheduler not called | FR-8 |

## 18b. Miss Card (`MissCardTests`) — frontend-spec §3.3, FR-18
| ID | Case | Expected | Traces |
|---|---|---|---|
| MC-01 | Yesterday had a miss; first open today | `shouldShowMissCard == true`; `lastMissCardShownDateKey = today` | FR-18 |
| MC-02 | Second evaluation the same day | false (once per date) | FR-18 |
| MC-03 | Dismiss | `missCardDismissedDateKey = today`; false for the rest of the day; true again after the next missed day | FR-18 |
| MC-04 | No misses yesterday | false | FR-18 |

## 19. Schema & Conventions (`SchemaTests`, `ConventionTests`) — data-spec §12, NFR-5
| ID | Case | Expected | Traces |
|---|---|---|---|
| SCH-01 | Open a V1 fixture store | loads without migration error | §12 |
| SCH-02 | All models are in `WinterArcSchemaV1.models` | reflection check | §12 |
| CONV-01 | No `Date()`, `Calendar.current`, `TimeZone.current` outside `SystemClock.swift` | grep over the app module sources | §1 |
| CONV-02 | No `import` of networking frameworks (`URLSession` usage) in the app module | grep | NFR-3 |
| CONV-06 | No colour literals in views — no `Color(red:green:blue:)`, `Color(white:)`, `#colorLiteral`, `.white`, `.black` or `UIColor(red:…)` outside `Palette.swift`; every colour comes from the asset catalog or a system semantic colour | grep over the app module sources, excluding `Palette.swift` | frontend-spec §6 |

## 19b. Performance (`PerformanceTests`, `LaunchPerformanceTests`) — NFR-2
Budgets are from frontend-spec §10. Measured on the iPhone 16 simulator, Debug build.

| ID | Case | Budget | Measured |
|---|---|---|---|
| PERF-01 | Worst-case catch-up: 90-day rollover × 7 habits (630 habit-days) in one save | < 1 s | **0.220 s** → 0.228 s after Frost |
| PERF-02 | All metrics (streak, score, heat-map) over a full 180-day × 7-habit arc | < 100 ms | **0.005 s** → 0.005 s after Frost |
| PERF-03 | Startup gate: store open + first rollover | < 300 ms | **0.006 s** → 0.007 s after Frost |

These three are data-layer measurements and were never the restyle's risk — they are re-run to
show it added no hidden cost, not because a gradient could have affected them.

**Cold launch.** `XCTApplicationLaunchMetric` reports ~1.3 s, but that figure includes XCUITest's
attach and instrumentation overhead and a Release run is no faster (just noisier), so it is not
comparable to the NFR-2 budget. The app therefore reports its own timing: `LaunchMetrics`
(DEBUG only) measures from the kernel's process start time — so dyld and pre-main work are
included — to the first interactive frame, and prints it under `LAUNCH-METRIC`. Read it with:

```
xcrun simctl launch --console-pty <udid> com.vipinpahwa.WinterArcApp --skip-welcome
```

Five cold launches with an active arc: 0.614 / 0.379 / 0.304 / 0.374 / 0.313 s — **median 0.374 s**
against a 1 s budget. The startup gate is 6 ms of that; the rest is process launch and first render.
Still to confirm on a physical device before submission.

**After the Frost restyle (2026-10-01):** 0.466 / 0.412 / 0.421 / 0.403 / 0.424 / 0.403 s —
**median 0.417 s**, a warm-up launch discarded. That is +0.043 s on the earlier median, roughly
11 %, and still less than half the 1 s budget. Treat the delta as indicative rather than
established: this run is tight (0.403–0.466) while the earlier one spanned 0.304–0.614, so the
difference sits near the resolution of the measurement. The plausible cause is the backdrop
gradient now being painted on the first frame.

**Not measured, and not measurable here: scroll.** §10's "no frame drops at 60 Hz with 7 habits
× 180 days" has no automated test, and nothing in §19b exercises rendering. The restyle's real
performance risk — a translucent fill and a shadow on every card, down a long scrolling list —
is therefore still unverified and stays a manual QA item on a physical device.

### 19c. Between arcs & the welcome gate (frontend-spec §3.1, §3.12)
| ID | Case |
|---|---|
| ENV-14 | The welcome gate opens only once an arc exists — building a draft does not set `hasCreatedArc` |
| ENV-15 | A restart also sets the flag (it delegates to `createArc`) |
| ENV-16 | `previousArc` is nil while an arc is current |
| ENV-17 | Completing the only arc routes to the between-arcs landing, not a bare setup form |
| ENV-18 | `previousArc` is the most recently ended arc, not the oldest |
| ENV-19 | Deleting the whole history falls through to `ArcSetupFlow` without the Welcome pitch returning |
| CONV-04 | Inflection markup (`^[…](inflect: true)`) only appears inside a `Text` literal — built as a `String` it renders verbatim, which shipped briefly in `BetweenArcsView` |
| `WelcomeGateTests` | Abandoning setup returns to the pitch on relaunch; creating an arc closes the gate permanently |
| `BetweenArcsTests` | A finished arc lands on the acknowledgement; *Start your next arc* opens setup carrying the previous pillars |

Run the between-arcs state by hand with `--reset --seed-between`.

### 19d. Palette & buttons (`ButtonStyleTests`, `PaletteContrastTests`) — frontend-spec §6, §3.13, NFR-7
Measured against the real asset catalogue at runtime, in both appearances, rather than against
hardcoded values — an earlier draft of the palette hardcoded sRGB stops and silently lost the
accent's dark-mode and Increase-Contrast variants.

| ID | Case | Measured |
|---|---|---|
| BTN-01 | The light accent carries white label text at 4.5:1. `DepthButtonStyle` only darkens downwards, so the accent is the button's lightest point and its worst case | **5.45:1** |
| BTN-02 | Increase Contrast makes the accent darker, not lighter | **9.61:1** vs 5.45:1 |
| BTN-03 | The label clears 4.5:1 in both appearances at the worst point of the gradient — undarkened top in light mode, fully darkened bottom in dark | light **5.45:1**, dark **4.70:1** |

**Palette suite (Frost).** `CardFill` is translucent, so the resolved card colour depends on which
backdrop stop is behind it. Every case below therefore resolves the card over **both**
`BackdropTop` and `BackdropBase` and asserts the **worse** of the two, in each of the four
appearance × contrast combinations. Thresholds: 4.5:1 for text, 3:1 for a graphical object.

PAL-05 and PAL-06 are **implemented and passing** — they shipped with the B-4 fix, because neither
needs a new token. The rest of the *Expected* column is computed from the §6 token values and is
what the suite must confirm at runtime once the restyle lands.

BTN-03's dark figure was 5.87:1 when first recorded and measures 4.70:1 today; the accent was
darkened during the M4 audit after that number was written down. It still clears 4.5:1.

| ID | Case | Threshold | Expected |
|---|---|---|---|
| PAL-01 | `label` on a `CardFill` panel, worst backdrop stop | 4.5:1 | system colour, passes by construction |
| PAL-02 | `secondaryLabel` on a `CardFill` panel — the eyebrow, "58 days left", pillar names | 4.5:1 | **does not pass, and did not before the restyle**: #3C3C43 at 60 % measures **3.44:1 on pure white**, 3.40:1 on a card over `BackdropMid`, 3.21:1 on the bare backdrop. Apple ships it this way; overriding it would break Bold Text and Increase Contrast adaptivity. Accepted, as §20 accepted it before — but *measured* now rather than assumed |
| PAL-03 | `Ember` streak count on a `CardFill` panel | 4.5:1 | light **5.11:1**, dark **6.72:1** |
| PAL-04 | The mockup's lighter ember (#C2622F) **fails** in light — a regression guard on the value chosen in §6 | 4.5:1 | **3.85:1 → must fail**, proving the suite would have caught it |
| PAL-05 | The done-checkbox glyph against the `Success` fill, both appearances (B-4) | 3:1 | **measured** — light **5.34:1**, dark **11.19:1** |
| PAL-06 | A white glyph against the dark-mode `Success` fill — regression guard for B-4 | 3:1 | **measured 1.88:1 — asserted to stay below 3** |
| PAL-07 | `CardEdge` against the backdrop either side of it — the card boundary must be perceivable | 3:1 | to measure; if it fails, the card needs the shadow/sheen to carry the edge, not the rim alone |
| PAL-08 | `Hairline` dividers against `CardFill` | 3:1 | to measure — these are decorative separators, so a miss means raising the alpha, not redesigning |
| PAL-09 | Heat levels 0–4 are each distinguishable from their neighbours | 3:1 between adjacent levels | to measure; `HeatEmpty` → `HeatLow` is the tightest pair |
| PAL-11 | Under Increase Contrast, `CardFill` resolves opaque and `CardEdge`/`Hairline` reach 30 % | — | asserts the flattening rule in §6 actually fires |
| PAL-12 | Every token in §6 defines all four appearance variants | — | asset-catalog reflection; catches a token added with only `any` |

### 19e. Reduce Motion (`MotionTests`, CONV-05) — frontend-spec §3.13, NFR-7
| ID | Case |
|---|---|
| MOT-01 | `Motion.animated` still performs its state change when Reduce Motion is on — only the animation is dropped |
| MOT-02 | …and performs it when Reduce Motion is off |
| MOT-03 | With no test override set, `Motion.isReduced` reads the real `UIAccessibility` setting |
| CONV-05 | No `.animation`, `.transition` or `withAnimation` outside `Motion.swift` and `ButtonStyles.swift` |

The SwiftUI paths (`calmAnimation`, `calmTransition`) read `accessibilityReduceMotion` from the
environment, which cannot be toggled from `simctl` — confirm those on a device with Reduce Motion on.

### 19f. Review prompt (`ReviewPromptTests`) — frontend-spec §3.14
| ID | Case |
|---|---|
| REV-01 | A seven-day run of complete days earns the prompt |
| REV-02 | Six days does not |
| REV-03 | The app never asks twice, at any streak length |
| REV-04 | A missed day breaks the run — earlier complete days do not count |
| REV-05 | A day counts only when *every* tracked habit is done |

Verify by hand with `--reset --seed-review`: six complete days behind today and today one habit
short. Ticking the last habit shows Apple's sheet after ~1.5 s. StoreKit reports no result, so
whether the sheet appears is the system's decision — in Debug it generally does.

## 20. Manual QA Checklist (replaces UI tests for v1)
Run on a physical iPhone and the iOS 18.0 and 26.5 simulators before submission. Tick each; record failures as issues referencing the FR.

**Journeys**
- [ ] UJ1 — Fresh install → Welcome → setup all steps → Start Arc → Today shows Day 1. Under 3 minutes. (G1)
- [ ] UJ2 — Toggle every habit; day-complete banner + haptic; kill and relaunch → state persisted. Three taps for a 3-habit day. (G2, FR-10)
- [ ] UJ3 — Progress shows score, streaks, pillar bars, heat-map; tap a past cell → DayDetail. (FR-12–16)
- [ ] UJ4 — Set device date forward one day with a habit unmarked → miss card on open; Grace Days: indicator decrements; exhaust budget → GraceDaysExhaustedView. (FR-17, FR-18)
- [ ] UJ5 — Set device date past end → ArcCompleteView → reflection → after photo → Done; arc appears in Archived. (FR-19–21)
- [ ] UJ6 — Setup with start 5 days ago, choose *Leave blank* → heat-map shows 5 unlogged cells → backfill one from Progress. (FR-22)
- [ ] UJ7 — Settings → Restart → setup pre-filled → Start → old arc archived as Abandoned. (FR-28)
- [ ] Switch ruleset mid-arc → preview shows resulting grace usage / failure before applying. (FR-29)
- [ ] Edit the "why" in Settings → shown on next miss card. (FR-30)

**Accessibility audit (M4)**

`AccessibilityAuditTests.testAuditEveryScreen` runs Xcode's audit over Welcome, both setup steps,
Today, Progress, Settings, the Grace Days cover and the completion flow, and attaches every issue
to the result bundle. It reports rather than fails, so one run inventories the app. Baseline after
the first pass: **74 → 67 issues**, triaged as follows.

| Category | Status |
|---|---|
| Label not human-readable | **Fixed** — decorative SF Symbols exposed their symbol name (`snowflake.slash`, `flag.checkered`); all now `accessibilityHidden` |
| Hit area is too small | **Fixed** — `GraceDaysIndicator` was 17pt tall; padded to 44pt |
| Contrast failed (Warning text) | **Fixed** — light palette was 2.5–4.3:1 on the grouped background; Warning, Success, Danger and Accent darkened to clear 4.5:1 |
| Contrast failed (prominent button) | **Accepted** — white on the app accent is 5.45:1; the audit flags Apple's own prominent buttons the same way |
| Contrast failed (2 × Settings, element not reported) | **Open** — the audit does not name the element; needs a manual Accessibility Inspector pass |
| Contrast nearly passed (39) | **Accepted** — secondary/tertiary system label colours, which Apple ships at these ratios |
| Text clipped (17) | **Fixed** — these were *not* `minimumScaleFactor` noise as first assumed; see §20a |
| Dynamic Type partially unsupported (4) | **Fixed** — the ring now scales with `@ScaledMetric` and drops its caption at AX sizes; see §20a |
| Potentially inaccessible text (4, Today) | **Open** — element not reported |

**Re-run after the Frost restyle (2026-10-01).** Total **67 → 53**. The composition changed more
than the count: "Contrast nearly passed" (39 before) collapsed to 4, and "Contrast failed" rose to
42. That reads alarming and is not. Those entries are overwhelmingly `secondaryLabel` and
`tertiaryLabel`, which fail on *any* light surface — 3.44:1 on pure white, before Frost existed.
The backdrop moves them to 3.21–3.40:1, which crosses the audit's internal bucket boundary without
being a new defect. Lightening the palette to recover it was computed and rejected: the best case
bought 0.03:1 for a visibly washed-out backdrop. See PAL-02.

Two entries *are* worth attention, both on the **Settings** `Picker` labelled "Edit window":
"Text clipped" and "Dynamic Type font sizes are partially unsupported", at **default** size. It is
a stock `Picker` with a `Label`, untouched by the restyle, and the AX5 pass below is clean on the
same screen — so the compact picker layout clips at default width and reflows at larger sizes.
Open; needs a manual Accessibility Inspector pass.

Prominent-button "Contrast failed" entries (`Set up my arc`, `Continue`, the failure-screen
buttons) remain accepted on the same grounds as the baseline: the audit flags Apple's own
`.borderedProminent` buttons identically, and BTN-01–03 measure the real ratios at 5.45:1 light
and 4.70:1 dark.


### 20a. Dynamic Type pass (NFR-7)
`DynamicTypeAuditTests.testAuditEveryScreenAtAX5` re-runs the audit over the same eight screens at
AX5 (`UICTContentSizeCategoryAccessibilityXXXL`), restricted to the `.dynamicType` and
`.textClipped` checks, and attaches a screenshot of each screen so the result can be judged by eye
rather than only by the audit's verdict.

The 17 "Text clipped" findings had been triaged as audit noise — the assumption being that the
audit counts `minimumScaleFactor` as clipping. The screenshots disproved that. At AX5 the findings
were real and severe:

- Today's day counter, the single most important number on the screen, rendered as `Day…`
- the ring's caption rendered as `consiste…`
- on the Grace Days failure screen, **both** actions rendered as `Restart…` and `Keep goin…`, so
  the user could not tell what either button did
- every feature row on Welcome truncated to one line

**Root cause.** Those screens were non-scrolling `VStack`s with `Spacer()`s. That layout cannot
overflow, so when the content grew past the viewport SwiftUI resolved it by compressing the `Text`
views — which truncates with an ellipsis instead of wrapping. Only 6 of the findings involved
`minimumScaleFactor` at all.

**Fixes.** `CenteredScrollView` keeps content centred while letting it scroll once it is taller
than the screen; `wrapsInsteadOfTruncating()` (`fixedSize(horizontal:vertical:)`) stops text being
compressed; `TodayHero` and its day counter switch to a vertical `AnyLayout` at accessibility
sizes so the text gets the full width; `ConsistencyRing` grows with `@ScaledMetric` (capped at
1.6×) and drops its caption at accessibility sizes, where the accessibility label already reads
"Consistency score"; `PrimaryButton` labels wrap.

**Result: 17 findings → 0.** All eight screens report clean at AX5 and were checked visually.

**Re-run after the Frost restyle (2026-10-01): still clean on all eight screens.** The 22 pt card radius, the new padding and the backdrop introduced no clipping and no Dynamic Type regression at AX5 — which is the result that mattered, since the restyle changed every surface the text sits on.


### 20b. Localization (NFR-8)
v1 ships English only, but every user-facing string now goes through the localization system, so
adding a language is a catalog change rather than a code change.

`Localizable.xcstrings` exists for both bundles — `WinterArcApp/` (177 keys) and
`WinterArcWidget/` (7) — and `xcstringstool` processes both on every build. No `.lproj` is
emitted, which is correct: every string is in the source language with no translations yet.

**What was bypassing it.** SwiftUI localizes `Text("literal")` automatically, but not
`Text(someString)`. Helpers that took UI copy as `String` — `StepHeader.title`,
`PrimaryButton.title`, `ProgressView.card`, `WelcomeView.bullet`, `LateStartStep.option`,
`DatesStep.quickPick`, `MissCard.message`, `ArcSetupViewModel.Step.title` — silently dropped their
literals out of extraction. They now take `LocalizedStringKey`. Strings that *are* user data
(habit and pillar names) correctly stay `String`.

**Interpolated copy.** `TodayHero.subline` and the Grace Days phrase were assembled as `String`
with a `day`/`days` ternary, so neither the sentence nor its plural reached the catalog. Both are
now `Text` with `^[\(n) day](inflect: true)`, which extracts as
`^[%lld day](inflect: true) left · %lld of %lld done` and hands pluralization to the system.

**Dates and numbers.** The heat-map's weekday initials were the hardcoded English list
`["M","T","W","T","F","S","S"]`; they now come from `DateKeyFormatter.weekdayInitials(locale:)`,
Monday-first to match the ISO week. In v1 this still resolves to English on every device, because
`Locale.current` negotiates against the app's supported localizations — so it is covered by unit
tests rather than a screenshot: **LOC-01** (Monday-first), **LOC-02** (fr ≠ en, starts with `L`),
**LOC-03** (a non-Latin locale still yields seven).

**Screens & states**
- [ ] Every screen in light and dark. (§6)
- [ ] Frost restyle: the backdrop gradient is continuous across the whole screen, and the navigation bar,
      tab bar and sheets keep their own system backgrounds rather than inheriting it. (§6)
- [ ] Cards read as distinct panels against the backdrop at the **top and the bottom** of a long scroll —
      the translucent fill is the one thing a static screenshot cannot prove. (§6)
- [x] Increase Contrast on: cards flatten to opaque, edges and hairlines strengthen. (§6, NFR-7) — verified on the simulator; the `CardEdge` hue flip is what makes the border visible in light.
- [ ] The done checkmark is clearly visible in **dark** mode — the specific failure in B-4. (NFR-7)
- [x] Every screen at default and AX3 Dynamic Type — no clipped text, no overlapping controls. (NFR-7) — automated at AX5 in §20a; device pass still worth a look.
- [ ] VoiceOver on Today, Progress, Setup: every control announced with label/value/hint; confetti not announced. (NFR-7)
- [ ] VoiceOver on a habit row: one element per row reading "Gym — Done, streak 13 days"; the rotor
      offers "Open day details" and activating it presents the day sheet. (NFR-7, FR-16)
- [ ] Reduce Motion on: no confetti; crossfades only. (NFR-7)
- [ ] Today with a future start date shows countdown and disabled list. (§3.3)
- [ ] Today after deleting all habits shows the empty state with a link to Settings. (§9)
- [ ] DayDetail outside the edit window shows disabled checkboxes and the caption. (NFR-6)
- [ ] Edit habits mid-arc: added habit appears today only; removed habit gone from Today, still in Progress history. (FR-23)
- [ ] Switch ruleset mid-arc shows the preview warning. (§3.8.2)

**System**
- [ ] Reminder fires at the chosen time with the correct body; turning it off cancels it; denying permission turns the toggle off with the caption. (FR-8)
- [ ] Widget (small, medium) shows correct counts; updates within seconds of a toggle; after midnight shows 0 / n; tapping opens Today. (FR-25)
- [ ] Before photo via camera and via library; skip works; after photo comparison; *Save to Photos* asks add-only permission. (FR-26)
- [ ] Airplane mode throughout — no behaviour change. (NFR-3)
- [ ] Change device time zone by ±12 h mid-arc → no duplicate or lost days. (NFR-5)
- [ ] Cold launch to interactive Today under 1 s on the oldest test device; startup gate placeholder visible, never stale data. (NFR-2) — 0.374 s median on simulator (§19b); device run outstanding.
- [x] Worst-case rollover: set the device date 90 days ahead on a 7-habit arc → catch-up completes in under 1 s. (NFR-2, §7) — automated as PERF-01, 0.220 s.
- [ ] Kill the app on the Grace Days failure screen → relaunch shows it again; choose Keep going → relaunch shows Today. (FR-31)
- [ ] Start a restart, cancel at step 3 → original arc unchanged. (FR-28)
- [x] Archive size < 20 MB in Xcode Organizer. (NFR-10) — **6.7 MB** unsigned Release build for `generic/platform=iOS`, before App Store thinning: 4.7 MB binary, 1.4 MB `Assets.car`, 492 KB widget extension. Reproduce with `xcodebuild build -configuration Release -destination 'generic/platform=iOS'` then `du -sh` the `.app`.
- [ ] Privacy manifest present with `1C8F.1`; App Privacy answers "Data Not Collected"; both usage strings (camera, photo-library add) present. (§8)
- [x] Screenshots captured on 6.7" and 6.1" in light mode for App Store Connect. — plus 6.9", which App Store Connect now asks for. In `design/screenshots/appstore/`, four per size (Welcome, Today, Progress, setup), at 1320×2868 / 1290×2796 / 1179×2556, status bar pinned to 9:41 with full bars. Regenerate with `design/screenshots/appstore/capture.sh`. They come from a DEBUG build because the seed launch arguments are DEBUG-only; the UI is identical.

## 21. Coverage Matrix
| Requirement | Automated cases | Manual |
|---|---|---|
| FR-1, FR-2 | DK-05, VAL-01–05 | UJ1 |
| FR-3, FR-4, FR-5 | VAL-06–11 | UJ1 |
| FR-6 | VAL-12–14, RS-01–04 | UJ1 |
| FR-7 | VAL-15 | UJ4 |
| FR-8 | VAL-16, RM-01–06, RO-19 | System |
| FR-9 | PH-01–03, DS-06 | UJ2 |
| FR-10 | EW-01–05 | UJ2 |
| FR-11 | RO-01–19 | UJ4 |
| FR-12 | STK-01–11, CS-08 | UJ3 |
| FR-13 | CS-01–06, CS-09 | UJ3 |
| FR-14 | CS-07 | UJ3 |
| FR-15 | DS-01–05, DS-08–09 | UJ3 |
| FR-16 | STK-06, CS-03, EWN-01–05, EW-08–09 | UJ3 |
| FR-17 | GD-01–13 | UJ4 |
| FR-18 | MC-01–04 | UJ4 |
| FR-19, FR-20 | LC-07, RF-03 | UJ5 |
| FR-21 | LC-08, PH-05 | UJ5 |
| FR-22 | HDS-04, CS-06, RO-09–11, EWN-04, GD-13 | UJ6 |
| FR-23 | HDS-06–07, STK-07–08, CS-10, RO-07–08, EW-07 | Screens |
| FR-24 | LC-05–06, PHO-03 | UJ7 |
| FR-25 | WS-01–07, EW-06 | System |
| FR-26 | PHO-01–04 | System |
| FR-27 | DK-08, RF-01–02, RF-04 | UJ3 |
| FR-28 | LC-01–04, LC-09–10 | UJ7 |
| FR-29 | RS-01–04 | Screens |
| FR-30 | — (Settings inline edit) | Screens |
| FR-31 | GD-10–12, PH-09–10, RO-18b, LC-11 | UJ4, System |
| FR-32 | — (M7; `CONV-02` must still pass with the share path in, which is the point of the design) | Screens |
| FR-34 | — (M7; assert quick start produces a valid arc — 3 pillars, ≥1 habit each — and that the full flow still reaches the same state) | UJ1, System |
| FR-35 | — (M7; assert a draft defaults `reminderEnabled == true` at hour 20, and that declining permission leaves the app usable, NFR-7) | UJ2, System |
| FR-33 | — (M8; assert the share action appears only from Day 7 and tracks FR-27's Monday refresh) | Screens |
| NFR-2 | — | System |
| NFR-3 | CONV-02 | System |
| NFR-4 | PHO-04 | System |
| NFR-5 | DK-01–04, DK-08, STK-10, RO-03, RO-12–16, EW-05, CONV-01 | System |
| NFR-6 | EWN-01–05 | Screens |
| NFR-7 | BTN-01–03, PAL-01–12, MOT-01–03, CONV-05, CONV-06, §20a | Screens |
| NFR-8, NFR-9, NFR-10 | — | System |

---
**Status:** Draft v3 · **Owner:** Vipin Pahwa · **Last updated:** 2026-10-01 (palette suite, CONV-06)
