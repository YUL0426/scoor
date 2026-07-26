//
//  ScoreSyncQueue.swift
//  Scoor
//
//  Durable outbox for score writes (spec-13 §5).
//
//  The contract that shapes this whole type: personal journaling works 100%
//  offline and a sync failure must never reach the user. So writes are recorded
//  locally first, an operation is appended here, and the flush is best-effort —
//  if it fails for a retryable reason the work stays queued for the next attempt.
//
//  Persisted to UserDefaults rather than SwiftData: the queue must survive a
//  crash mid-flush, it is small (one op per day-edit), and keeping it out of the
//  model container avoids a migration for what is transient bookkeeping.
//

import Foundation

/// One pending server write. `day` is the merge key — the server enforces
/// `unique (user_id, day)` and resolves by `clientUpdatedAt`.
struct ScoreSyncOperation: Codable, Equatable, Identifiable {

    enum Kind: String, Codable { case upsert, delete }

    let id: UUID
    let kind: Kind
    let userId: UUID
    /// Local calendar day, `yyyy-MM-dd`. Matches `scores.day`.
    let day: String
    let value: Int
    let reason: String?
    let mood: String?
    /// Local write time. The server keeps the newest and discards older writes,
    /// which is the same "one score per day, last write wins" rule the app
    /// already applies locally — so the user's mental model is unchanged.
    let clientUpdatedAt: Date
    /// Attempts so far; used to back off and eventually drop poison operations.
    var attempts: Int = 0

    static func upsert(_ score: Score, calendar: Calendar = .current) -> ScoreSyncOperation {
        ScoreSyncOperation(
            id: UUID(),
            kind: .upsert,
            userId: score.userId,
            day: ScoreSyncFormat.day(from: score.date, calendar: calendar),
            value: score.value,
            reason: score.reason,
            mood: score.mood?.rawValue,
            clientUpdatedAt: Date()
        )
    }

    static func delete(_ score: Score, calendar: Calendar = .current) -> ScoreSyncOperation {
        ScoreSyncOperation(
            id: UUID(),
            kind: .delete,
            userId: score.userId,
            day: ScoreSyncFormat.day(from: score.date, calendar: calendar),
            value: score.value,
            reason: nil,
            mood: nil,
            clientUpdatedAt: Date()
        )
    }
}

enum ScoreSyncFormat {
    /// `scores.day` is a DATE, not a timestamp — it must be the user's local
    /// calendar day, not UTC. Recording at 09:00 KST is "today" even though it is
    /// still yesterday in UTC, and getting this wrong shifts entries a day on the
    /// calendar screen.
    static func day(from date: Date, calendar: Calendar = .current) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    static func date(fromDay day: String, calendar: Calendar = .current) -> Date? {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: day)
    }
}

// MARK: - Queue

actor ScoreSyncQueue {

    private let defaultsKey = "scoor.sync.scoreQueue"
    private let lastSyncedKey = "scoor.sync.lastSyncedAt"
    /// Past this, an operation is assumed permanently broken and dropped rather
    /// than retried forever on every launch. The local record still stands — the
    /// user loses backup of that day, not the day itself.
    private let maxAttempts = 8

    private let defaults: UserDefaults
    private var pending: [ScoreSyncOperation]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.pending = Self.load(from: defaults, key: "scoor.sync.scoreQueue")
    }

    var count: Int { pending.count }
    var operations: [ScoreSyncOperation] { pending }

    /// Timestamp of the last successful pull. Shown in Settings as "마지막 동기화"
    /// — the only place sync surfaces in the UI at all.
    var lastSyncedAt: Date? {
        defaults.object(forKey: lastSyncedKey) as? Date
    }

    func markSynced(at date: Date = Date()) {
        defaults.set(date, forKey: lastSyncedKey)
    }

    /// Append an operation, collapsing any earlier pending write for the same day.
    /// Editing today's score five times offline should upload once, not five
    /// times — and only the last value is correct anyway.
    func enqueue(_ operation: ScoreSyncOperation) {
        pending.removeAll { $0.userId == operation.userId && $0.day == operation.day }
        pending.append(operation)
        persist()
    }

    func remove(_ id: UUID) {
        pending.removeAll { $0.id == id }
        persist()
    }

    /// Record a failed attempt, dropping the operation once it is clearly poison.
    func recordFailure(_ id: UUID) {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return }
        pending[index].attempts += 1
        if pending[index].attempts >= maxAttempts {
            pending.remove(at: index)
        }
        persist()
    }

    func removeAll() {
        pending.removeAll()
        defaults.removeObject(forKey: lastSyncedKey)
        persist()
    }

    // MARK: Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    private static func load(from defaults: UserDefaults, key: String) -> [ScoreSyncOperation] {
        guard let data = defaults.data(forKey: key),
              let ops = try? JSONDecoder().decode([ScoreSyncOperation].self, from: data)
        else { return [] }
        return ops
    }
}
