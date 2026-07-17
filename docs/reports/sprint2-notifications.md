# Sprint 2 — Task 2: Daily Reminder System

**Date:** 2026-06-03
**Branch:** `sprint2-foundations`
**Status:** ✅ Complete — 8 unit tests passing, live Settings UI verified

## Goal

Increase retention with a complete local-notification daily reminder.

## Architecture

Follows the project's established service pattern (protocol + mock + real, registered in `AppServices`, prefs in `UserDefaults` under `scoor.*`).

```
AppServices.notificationService : NotificationServiceProtocol
   ├─ LocalNotificationService   (production — UNUserNotificationCenter + UserDefaults)
   └─ MockNotificationService    (previews/tests — in-memory auth + UserDefaults, no UN calls)

SettingsView ──reads/writes──► notificationService
ScoorApp.task ──refreshSchedule() on launch──► reschedules from stored prefs
```

### `NotificationServiceProtocol` (`Scoor/Services/NotificationService.swift`)

```swift
nonisolated protocol NotificationServiceProtocol {
    var isEnabled: Bool { get }
    var reminderTime: DateComponents { get }
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    @discardableResult func requestAuthorization() async -> Bool
    func setEnabled(_:) async
    func setReminderTime(_:) async
    func nextReminderDate() -> Date?
    func refreshSchedule() async        // cancels + reschedules the single daily request
}
```

### Behavior

- **Defaults:** enabled = **true**, time = **21:00** (`UserDefaults.register(defaults:)` so a missing key reads `true`, not `false`).
- **Single repeating request** id `scoor.dailyReminder` via `UNCalendarNotificationTrigger(dateMatching: hour/minute, repeats: true)`.
- **Copy:** title **"Today's Scoor"**, body **"What score would you give today?"** (constants in `NotificationCopy`).
- **Persistence keys:** `scoor.notif.enabled`, `scoor.notif.hour`, `scoor.notif.minute`.
- **Denied-permission handling:** stored pref is kept, scheduling is skipped, and Settings surfaces an **"enable in Settings"** CTA (`UIApplication.openSettingsURLString`). No crash.
- **Launch:** `ScoorApp` calls `refreshSchedule()` (guarded off under the XCTest host) so prefs survive relaunch/reinstall.

### Settings UI (`Scoor/Views/Settings/SettingsView.swift`)

Rebuilt from dead placeholder `Label`s into a working form:
- **Daily Reminder** toggle (requests permission on first enable).
- **Reminder Time** `DatePicker(.hourAndMinute)` (hidden when off).
- **Next reminder** row (formatted `nextReminderDate()`), or the denied-state CTA.
- Footer shows the exact notification copy. About/Preferences sections preserved.

> **Reachability fix (important):** MyPage uses `.navigationBarHidden(true)`, which hid the toolbar gear → Settings was **unreachable** in the shipping build (the reminder UI would have been dead). Added a visible, accessible (`settingsButton`) gear overlay on MyPage, and the sheet now explicitly injects `AppServices`. Confirmed reachable by UI test.

## Screenshots

| File | Shows |
|---|---|
| `sprint2-screenshots/02-mypage.png` | MyPage with the new settings gear |
| `sprint2-screenshots/03-settings-reminder.png` | Reminder on, 9:00 PM, "Next reminder: Wed, Jun 3 · 9:00 PM", copy footer |
| `sprint2-screenshots/04-…` / `05-…` | toggle off / on |

## Test results

`ScoorTests/NotificationServiceTests` — **8 passed, 0 failed**:
- default enabled + 21:00
- toggle off disables & clears schedule (next == nil)
- toggle on schedules when authorized
- permission granted path
- **permission denied → does NOT schedule** (`isActive == false`)
- time change persists
- **app relaunch reads stored prefs** (new instance, same suite)
- `nextReminderDate` is in the future and matches the configured time

(Real `UNUserNotificationCenter` permission + OS scheduling are validated via the simulator/Settings UI, since auth can't run headlessly.)

## Notes / tech debt

- The launch `refreshSchedule()` is skipped under the unit-test host (`AppEnvironment.isRunningUnitTests`) because `UNUserNotificationCenter` is unstable in that context.
- Service classes are `nonisolated` — see the QA report for why (avoids a MainActor-isolated-deinit runtime crash).
