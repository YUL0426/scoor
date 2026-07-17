# Sprint 2 — Foundations Phase QA Report

**Date:** 2026-06-03
**Branch:** `sprint2-foundations`
**Scope:** Task 1 (Streak unification), Task 2 (Daily reminders), Task 3 (Recap sharing) + ScoorTests unit-test target.
**Deferred (not in this phase):** Task 4 (Branding), Task 5 (Onboarding activation).

## Summary

| Area | Result |
|---|---|
| App build (iPhone 17 Pro sim) | ✅ green (baseline + after each task) |
| **New unit tests (`ScoorTests`)** | ✅ **28 / 28 passing** |
| New Foundations UI test | ✅ passing |
| Pre-existing UI suite (Sprint1 / Persistence) | ⚠️ 2 failures — **pre-existing, in score-input keypad flow, NOT caused by this phase** (see Regression) |

### New unit-test breakdown (28)
- `StreakServiceTests` — 12
- `NotificationServiceTests` — 8
- `RecapShareTests` — 4
- `RecapSnapshotTests` — 4 (also emit the recap screenshots)

## Validation performed

| Requirement | Evidence |
|---|---|
| Streak: consecutive / missed / same-day / restart / timezone | `StreakServiceTests` (12) |
| Streak shown consistently across Home/Stats/MyPage | Single source `StreakService`; Stats live screenshot `06-stats.png` (“1 Days”) |
| Notification permission granted / denied | `NotificationServiceTests` granted + denied paths |
| Notification toggle off/on, time change, relaunch | `NotificationServiceTests`; Settings UI `03/04/05` |
| Default enabled + 9:00 PM | `testDefaultEnabledAndNinePM`; `03-settings-reminder.png` |
| Reminder copy “Today's Scoor” / “What score…” | `NotificationCopy`; visible in `03-settings-reminder.png` footer |
| Recap render high-res, light + dark | `RecapShareTests` (1080×1920, 9:16); `10–13` PNGs |
| Recap save / share / Instagram wired (no empty closures) | `InstagramStoryShareSheet` rewired; service methods |
| **Settings reachable** | UI test asserts `settingsButton` → “Daily Reminder” reachable |

Screenshots: `docs/reports/sprint2-screenshots/`.

## Regression testing

Full suite (all targets) run on iPhone 17 Pro: **35 tests, 33 passed, 2 failed.**

The 2 failures:
- `ScoorPersistenceUITests.testEndToEndPersistenceAndRegression` — fails at *“Home should display the created score 73”* (score never created) and a calendar selector ambiguity (`StaticText "1"` vs `calendar-day-1`).
- `ScoorSprint1UITests.test1RecentCardEditFlow` — fails at *“Keypad did not appear” / “Keypad digit 5 missing”* when entering a score from a calendar cell.

**Root cause — the score-entry keypad does not appear in the current working tree.** Both failures (and `test2CalendarDeleteFlow` in isolation) block on the numeric keypad / score-input sheet.

**Attribution — NOT caused by this phase:**
- This phase added/changed only: `StreakService`, `NotificationService`, `RecapShareService`, `RecapShareView`, the streak call-sites, `SettingsView`, the Stats share sheet, `AppServices`, `ScoorApp`, and the test target. **None touch** the score-entry keypad, `ScoreHomeView`, `ScoreInputViewModel`, score persistence, or Home recent cards.
- Those score-input files carried **uncommitted in-progress Sprint 2-A edits before this session began** (visible in the session-start `git status`).
- The only overlap with these tests' paths is the MyPage settings-gear overlay (positioned top-trailing, away from the calendar grid) and the MyPage streak number — neither affects keypad presentation.
- **Baseline confirmation (decisive):** the same two tests were run against the clean base commit `9864171` in a separate git worktree — i.e. *before* the Sprint 2-A in-progress work and *before* this phase. **Both fail there too (2/2 failed).** The keypad/score-input breakage therefore pre-dates everything in this phase; it is a long-standing pre-existing failure, definitively not a regression introduced here.

## Known issues

1. **Score-entry keypad not appearing** (long-standing pre-existing failure — reproduces at base commit `9864171`) → breaks score create/edit/delete UI tests. **Highest priority to fix before beta**, but outside this phase's scope.
2. Live recap **share-sheet** end-to-end screenshot not auto-captured — Monthly-tab scroll automation was flaky. The rendered card/story PNGs (`10–13`) are the authoritative visuals; sheet actions are wired and unit-tested.
3. Recap mini-heatmap uses the last 14 scored intensities (not a strict calendar layout) — cosmetic.

## Technical debt

1. **MainActor-isolated deinit crash (resolved here, latent elsewhere).** The project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so service classes get a MainActor-isolated `deinit`; deallocating one off the main thread (e.g. in unit tests) double-frees in the Swift back-deploy runtime (`swift_task_deinitOnExecutorMainActorBackDeploy`). Fixed by marking the notification service `nonisolated`. **`MockScoreService`, `MockUserService`, `MockGuestbookService` share this latent issue** and should be made `nonisolated` before they get unit tests.
2. **Settings reachability** was broken (`navigationBarHidden(true)` hid the toolbar gear). Fixed with an overlay button; the deprecated `.navigationBarHidden` should be migrated to `.toolbar(.hidden, for:)` project-wide and Settings entry points audited.
3. **Launch reminder scheduling is skipped under the XCTest host** (`AppEnvironment.isRunningUnitTests`) because `UNUserNotificationCenter` is unstable there — revisit if integration tests are added.
4. Hardcoded grays in `StatsView` (e.g. `Color(red:0.55,…)`) bypass design tokens — fold into Task 4 (Branding).
5. The pre-existing **score-input keypad regression** (Known issue 1) needs a dedicated fix + the score-CRUD UI tests re-greened.

## Sign-off

Tasks 1–3 are functionally complete, unit-tested, and verified on-device (simulator). No regression is attributable to this phase. Recommend fixing the pre-existing keypad regression next, then proceeding to Tasks 4–5.
