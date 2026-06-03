# Changelog

All notable changes to Scoor are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.1.0-alpha] - 2026-06-03

First internal alpha — Phase 1, Sprint 0–1. Establishes a persistent core
journaling experience with edit, delete, and profile persistence, verified
end-to-end.

### Added

- SwiftData-backed score persistence (`SwiftDataScoreService`) with a single
  app-wide `ModelContainer`; scores survive app restarts.
- Home recent card → edit flow (opens the score sheet in edit mode for that day).
- Calendar score deletion with a confirmation dialog.
- Profile bio field with persistence and display in the profile header.
- End-to-end UI test suites: `ScoorPersistenceUITests` and `ScoorSprint1UITests`.

### Improved

- `scoorScoreStoreDidChange` notifications keep Home, Calendar, and Statistics
  in sync after every write.
- Unified day-level aggregation for Calendar and Statistics via `ScoreEntry` /
  `ScoreCalendarIndex`, including a reason-present indicator on calendar cells.
- Consistent 0–100 integer score scale across World map, detail, and feed.
- DEBUG logging on save/load/delete paths for QA traceability.

### Fixed

- User identity no longer regenerates on every launch — the current user ID is
  persisted in `UserDefaults` (`scoor.currentUserId`), so persisted scores stay
  attached to the same user across restarts.
- Calendar / Statistics day-key drift resolved by consistently using
  `Calendar.current`'s `startOfDay`.

[v0.1.0-alpha]: https://github.com/Scoor/Scoor/releases/tag/v0.1.0-alpha
