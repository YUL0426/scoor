//
//  Score.swift
//  Scoor
//

import Foundation

struct Score: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var value: Int          // 0–100
    var reason: String?     // max 200 chars
    let date: Date          // calendar day (no time)
    var locationId: UUID?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        value: Int,
        reason: String? = nil,
        date: Date = .now,
        locationId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.value = min(100, max(0, value))
        if let r = reason, !r.isEmpty {
            self.reason = String(r.prefix(200))
        } else {
            self.reason = reason
        }
        self.date = date
        self.locationId = locationId
        self.createdAt = createdAt
    }
}

// MARK: - Calendar / stats single source of truth (per calendar day)

/// One row per calendar day for UI layers (Stats, My Page). Built from persisted `Score` records.
struct ScoreEntry: Equatable, Hashable {
    /// `Calendar.current.startOfDay(for:)` for the entry’s day.
    let calendarDay: Date
    let score: Int
    let reason: String?

    init(calendarDay: Date, score: Int, reason: String?) {
        self.calendarDay = calendarDay
        self.score = score
        self.reason = reason
    }

    init(from score: Score, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: score.date)
        self.init(calendarDay: day, score: score.value, reason: score.reason)
    }
}

enum ScoreCalendarIndex {
    /// Last write wins for duplicate scores on the same day (matches previous app behavior).
    static func entriesByDay(from scores: [Score], calendar: Calendar = .current) -> [Date: ScoreEntry] {
        var result: [Date: ScoreEntry] = [:]
        for s in scores {
            let day = calendar.startOfDay(for: s.date)
            result[day] = ScoreEntry(from: s, calendar: calendar)
        }
        return result
    }
}

extension Notification.Name {
    /// Posted when `MockScoreService` (or future store) mutates scores so tabs can reload.
    static let scoorScoreStoreDidChange = Notification.Name("ScoorScoreStoreDidChange")
}

