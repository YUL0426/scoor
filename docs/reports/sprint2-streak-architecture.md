# Sprint 2 — Task 1: Streak Unification

**Date:** 2026-06-03
**Branch:** `sprint2-foundations`
**Status:** ✅ Complete — 12 unit tests passing

## Problem

Streak ("연속 기록") was computed in **three** places with subtly divergent logic, and one trend-based "streak" that is unrelated:

| Location | Behavior | Issue |
|---|---|---|
| `HomeViewModel.computeStreak` | skip-today-if-missing, count back | duplicate |
| `StatsViewModel.computeStreak` | same logic, used for weekly + share | duplicate |
| `MyPageView.currentStreak` (inline) | **does NOT** skip a missing today → showed `0` before today's entry | duplicate **+ inconsistent** |
| `FeedbackEngine.upward/downwardStreak` | value-trend, not day-consecutive | **left untouched** (different concept) |

The MyPage variant disagreed with Home/Stats whenever the user hadn't scored *yet today*: Home/Stats kept the streak "alive", MyPage showed `0`.

## Resolution

A single source of truth — **`Scoor/Services/StreakService.swift`** (stateless `enum`, pure derivation from the already-loaded day index). Unified rule (product decision):

> **A streak stays alive through today.** If yesterday was scored, the streak shows even before today's entry; it only resets once a full day is missed.

This is the Home/Stats behavior; **MyPage now matches it** — the one intentional behavior change.

### Architecture (before → after)

```
BEFORE                                   AFTER
──────                                   ─────
HomeViewModel.computeStreak ─┐
StatsViewModel.computeStreak ─┼─ 3 copies   HomeViewModel ─┐
MyPageView.currentStreak ────┘  (divergent) StatsViewModel ─┼─► StreakService.currentStreak(
                                            MyPageView ─────┘     entriesByDay:today:calendar:)
                                                                  (single source of truth)
```

`StreakService` consumes the canonical `[Date: ScoreEntry]` day index produced by `ScoreCalendarIndex.entriesByDay(from:)` (`Scoor/Models/Score.swift`), so it inherits last-write-wins-per-day semantics for free.

### API

```swift
enum StreakService {
    static func currentStreak(entriesByDay: [Date: ScoreEntry], today: Date, calendar: Calendar = .current) -> Int
    static func longestStreak(entriesByDay: [Date: ScoreEntry], calendar: Calendar = .current) -> Int   // new capability
    static func streak(entriesByDay:today:calendar:) -> StreakResult                                     // current + longest
}
```

`calendar` and `today` are injectable → fully deterministic & timezone-testable. `longestStreak` is new (surfaced later for a "best streak" stat; computed now for test coverage).

## Files modified / added / removed

| Change | File |
|---|---|
| **Added** | `Scoor/Services/StreakService.swift` |
| **Added** | `ScoorTests/StreakServiceTests.swift` (12 tests) |
| **Modified** | `Scoor/ViewModels/HomeViewModel.swift` — delegate, deleted private `computeStreak` |
| **Modified** | `Scoor/ViewModels/StatsViewModel.swift` — delegate (weekly + share), deleted private `computeStreak` |
| **Modified** | `Scoor/Views/MyPage/MyPageView.swift` — delegate, deleted inline loop |
| **Removed (logic)** | 3 duplicate implementations (~36 lines) |

Published property names (`streakDays`, `currentStreakDays`, `shareStreakDays`) were preserved, so no view bindings changed. UI is byte-identical except MyPage's documented value alignment.

## Test results

`ScoorTests/StreakServiceTests` — **12 passed, 0 failed**:

- consecutive days (incl. today)
- missed day breaks streak
- multiple entries same day == 1
- today-missing-but-yesterday-present **stays alive**
- neither today nor yesterday == 0
- empty == 0
- longest streak (+ single-day)
- combined current+longest result
- **timezone/DST**: streak survives a spring-forward (America/New_York) boundary
- time-of-day independence (startOfDay normalization)
- **app-restart determinism**: identical streak from a re-indexed (shuffled) score set

## Verification

Live UI (`ScoorSprint2FoundationsUITests`) confirms the Stats screen shows **"CURRENT STREAK · 1 Days"** sourced from the unified service (see `sprint2-screenshots/06-stats.png`).
