//
//  MockScoreService.swift
//  Scoor
//

import Foundation

final class MockScoreService: ScoreServiceProtocol {
    private var storage: [Score] = []

    /// Use for previews: pre-fill with sample scores so charts/calendar show data.
    init(seedScores: [Score] = []) {
        storage = seedScores.sorted { $0.date > $1.date }
    }

    func saveScore(_ score: Score) async throws {
        let calendar = Calendar.current
        storage.removeAll { calendar.isDate($0.date, inSameDayAs: score.date) && $0.userId == score.userId }
        storage.append(score)
        storage.sort { $0.date > $1.date }
        #if DEBUG
        let day = calendar.startOfDay(for: score.date)
        print("[Scoor] MockScoreService saveScore userId=\(score.userId) score=\(score.value) reason=\(score.reason != nil) calendarDay=\(day)")
        #endif
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
    }

    func getTodaysScore(userId: UUID) async -> Score? {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return storage.first { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }
    }

    func getScoreHistory(userId: UUID, limit: Int = 365) async -> [Score] {
        let rows = storage.filter { $0.userId == userId }.prefix(limit).map { $0 }
        #if DEBUG
        print("[Scoor] MockScoreService getScoreHistory userId=\(userId) count=\(rows.count)")
        #endif
        return rows
    }

    func getScoresForDate(userId: UUID, date: Date) async -> [Score] {
        storage.filter { $0.userId == userId && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func deleteScore(_ score: Score) async throws {
        storage.removeAll { $0.id == score.id }
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
    }

    func deleteAllScores() async throws {
        storage.removeAll()
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
    }

    /// Mirrors `SwiftDataScoreService.reassignScores` — newer record wins per day.
    @discardableResult
    func reassignScores(from oldUserId: UUID, to newUserId: UUID) async throws -> [Score] {
        guard oldUserId != newUserId else { return [] }
        let calendar = Calendar.current

        let incoming = storage.filter { $0.userId == oldUserId }
        guard !incoming.isEmpty else { return [] }

        var byDay: [Date: Score] = [:]
        for score in storage where score.userId == newUserId {
            byDay[calendar.startOfDay(for: score.date)] = score
        }

        var moved: [Score] = []
        for score in incoming {
            let day = calendar.startOfDay(for: score.date)
            if let incumbent = byDay[day] {
                guard score.createdAt > incumbent.createdAt else {
                    storage.removeAll { $0.id == score.id }
                    continue
                }
                storage.removeAll { $0.id == incumbent.id }
            }
            let rekeyed = Score(
                id: score.id,
                userId: newUserId,
                value: score.value,
                reason: score.reason,
                mood: score.mood,
                date: score.date,
                locationId: score.locationId,
                createdAt: score.createdAt
            )
            storage.removeAll { $0.id == score.id }
            storage.append(rekeyed)
            byDay[day] = rekeyed
            moved.append(rekeyed)
        }
        storage.sort { $0.date > $1.date }
        NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
        return moved
    }
}
