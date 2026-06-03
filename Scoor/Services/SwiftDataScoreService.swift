//
//  SwiftDataScoreService.swift
//  Scoor
//
//  Real persistence for daily scores, backed by SwiftData (`ScoreModel`).
//  Drop-in replacement for `MockScoreService` — same `ScoreServiceProtocol`
//  contract and the same "one score per calendar day, last write wins"
//  behavior the app already relies on.
//
//  Runs on the main actor because it uses the app container's `mainContext`.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataScoreService: ScoreServiceProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Write

    /// Create or update today's (or the given day's) score.
    /// Mirrors `MockScoreService`: removes any existing record for the same
    /// user + calendar day, then inserts the new one — so editing an existing
    /// scoor overwrites it in place.
    func saveScore(_ score: Score) async throws {
        let (dayStart, dayEnd) = Self.dayBounds(for: score.date)
        let userId = score.userId

        let descriptor = FetchDescriptor<ScoreModel>(
            predicate: #Predicate { model in
                model.userId == userId && model.date >= dayStart && model.date < dayEnd
            }
        )
        let existing = try modelContext.fetch(descriptor)
        for model in existing {
            modelContext.delete(model)
        }

        modelContext.insert(ScoreModel(from: score))
        try modelContext.save()

        #if DEBUG
        print("[Scoor] SwiftDataScoreService saveScore userId=\(score.userId) score=\(score.value) reason=\(score.reason != nil) day=\(dayStart)")
        #endif
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
    }

    /// Delete a specific score record by id. No-op if it no longer exists.
    func deleteScore(_ score: Score) async throws {
        let id = score.id
        let descriptor = FetchDescriptor<ScoreModel>(
            predicate: #Predicate { $0.id == id }
        )
        let matches = try modelContext.fetch(descriptor)
        guard !matches.isEmpty else { return }
        for model in matches {
            modelContext.delete(model)
        }
        try modelContext.save()

        #if DEBUG
        print("[Scoor] SwiftDataScoreService deleteScore id=\(id) removed=\(matches.count)")
        #endif
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
    }

    // MARK: - Read

    func getTodaysScore(userId: UUID) async -> Score? {
        let (dayStart, dayEnd) = Self.dayBounds(for: Date())
        var descriptor = FetchDescriptor<ScoreModel>(
            predicate: #Predicate { model in
                model.userId == userId && model.date >= dayStart && model.date < dayEnd
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first?.toScore()
    }

    func getScoreHistory(userId: UUID, limit: Int = 365) async -> [Score] {
        var descriptor = FetchDescriptor<ScoreModel>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = max(0, limit)
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        #if DEBUG
        print("[Scoor] SwiftDataScoreService getScoreHistory userId=\(userId) count=\(rows.count)")
        #endif
        return rows.map { $0.toScore() }
    }

    func getScoresForDate(userId: UUID, date: Date) async -> [Score] {
        let (dayStart, dayEnd) = Self.dayBounds(for: date)
        let descriptor = FetchDescriptor<ScoreModel>(
            predicate: #Predicate { model in
                model.userId == userId && model.date >= dayStart && model.date < dayEnd
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.map { $0.toScore() }
    }

    // MARK: - Helpers

    /// Half-open `[startOfDay, startOfNextDay)` bounds. `#Predicate` can't call
    /// `Calendar.isDate(_:inSameDayAs:)`, so day filtering is done with a range.
    private static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return (start, end)
    }
}
