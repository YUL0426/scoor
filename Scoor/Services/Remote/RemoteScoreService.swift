//
//  RemoteScoreService.swift
//  Scoor
//
//  Local-first score sync (spec-13 §5, C1).
//
//  This is a decorator, not a replacement: every read and write goes to the
//  wrapped local service first and the server is a backup + multi-device layer
//  behind it. That ordering is the feature — the app must journal with no
//  network, so the remote half is only ever allowed to fail silently.
//
//  Conflict resolution is last-write-wins on (user_id, day) by client_updated_at,
//  which is the rule the app already applies locally, so a user with two devices
//  sees the same "one score per day, newest edit wins" behavior they already know.
//

import Foundation

@MainActor
final class RemoteScoreService: ScoreServiceProtocol {

    private let local: ScoreServiceProtocol
    private let client: SupabaseHTTPClient
    private let queue: ScoreSyncQueue
    private let calendar: Calendar

    /// Guards against overlapping syncs — foreground + sign-in can fire together.
    private var syncTask: Task<Void, Never>?

    init(local: ScoreServiceProtocol,
         client: SupabaseHTTPClient,
         queue: ScoreSyncQueue = ScoreSyncQueue(),
         calendar: Calendar = .current) {
        self.local = local
        self.client = client
        self.queue = queue
        self.calendar = calendar
    }

    // MARK: - Writes (local first, then queue)

    func saveScore(_ score: Score) async throws {
        // Local write is the one that is allowed to throw. If it fails the user
        // must know; if the upload fails they must not.
        try await local.saveScore(score)
        await queue.enqueue(.upsert(score, calendar: calendar))
        scheduleFlush()
    }

    func deleteScore(_ score: Score) async throws {
        try await local.deleteScore(score)
        await queue.enqueue(.delete(score, calendar: calendar))
        scheduleFlush()
    }

    /// Account deletion (P0-4). Clears local rows and drops any queued uploads —
    /// the server side is handled by the account/delete Edge Function, which
    /// CASCADEs the rows away, so replaying these afterwards would resurrect data
    /// the user just asked to erase.
    func deleteAllScores() async throws {
        try await local.deleteAllScores()
        await queue.removeAll()
    }

    /// Adopt records written before sign-in (spec-13 §7). The local re-key is what
    /// makes the history visible again; queueing the moved rows is what gets them
    /// to the server. Each keeps its original write time so last-write-wins stays
    /// honest against edits already on the server from another device.
    @discardableResult
    func reassignScores(from oldUserId: UUID, to newUserId: UUID) async throws -> [Score] {
        let moved = try await local.reassignScores(from: oldUserId, to: newUserId)
        for score in moved {
            await queue.enqueue(.upsert(score, calendar: calendar, clientUpdatedAt: score.createdAt))
        }
        return moved
    }

    /// Queue every locally held record for upload without touching the rows.
    ///
    /// Needed for the account whose ids already match but whose history predates
    /// the sync layer: nothing was ever queued for those days, so a re-key moves
    /// nothing and the backup would stay empty until each day is edited again.
    func enqueueBackfill(userId: UUID) async {
        for score in await local.getScoreHistory(userId: userId, limit: 3650) {
            await queue.enqueue(.upsert(score, calendar: calendar, clientUpdatedAt: score.createdAt))
        }
    }

    // MARK: - Reads (always local — never blocked on network)

    func getTodaysScore(userId: UUID) async -> Score? {
        await local.getTodaysScore(userId: userId)
    }

    func getScoreHistory(userId: UUID, limit: Int) async -> [Score] {
        await local.getScoreHistory(userId: userId, limit: limit)
    }

    func getScoresForDate(userId: UUID, date: Date) async -> [Score] {
        await local.getScoresForDate(userId: userId, date: date)
    }

    // MARK: - Sync

    /// Full sync: push the outbox, then pull anything newer from other devices.
    /// Call on foreground and after sign-in. Never throws — callers are UI paths
    /// that must not react to sync outcomes.
    func sync(userId: UUID) {
        guard syncTask == nil else { return }
        syncTask = Task { [weak self] in
            guard let self else { return }
            await self.push()
            await self.pull(userId: userId)
            self.syncTask = nil
        }
    }

    /// Last successful pull, for the Settings "마지막 동기화" row (spec-13 §5).
    func lastSyncedAt() async -> Date? {
        await queue.lastSyncedAt
    }

    private func scheduleFlush() {
        Task { [weak self] in await self?.push() }
    }

    /// Upload queued operations oldest-first. Stops on the first retryable error
    /// (offline) so we don't burn attempts on a dead connection; drops operations
    /// the server will never accept.
    private func push() async {
        for operation in await queue.operations {
            do {
                try await upload(operation)
                await queue.remove(operation.id)
            } catch let error as APIError {
                if error.isRetryable {
                    await queue.recordFailure(operation.id)
                    return
                }
                // Non-retryable: the write is malformed or forbidden. Keeping it
                // would block every later operation behind it forever.
                await queue.remove(operation.id)
                #if DEBUG
                print("[Scoor] sync dropped op \(operation.id): \(error.localizedDescription)")
                #endif
            } catch {
                await queue.recordFailure(operation.id)
                return
            }
        }
    }

    private func upload(_ operation: ScoreSyncOperation) async throws {
        switch operation.kind {
        case .upsert:
            let row = ScoreRow(
                userId: operation.userId,
                day: operation.day,
                value: operation.value,
                reason: operation.reason,
                mood: operation.mood,
                clientUpdatedAt: operation.clientUpdatedAt,
                deletedAt: nil
            )
            try await client.send(try .upsert("scores", values: [row], onConflict: "user_id,day"))

        case .delete:
            // Tombstone rather than DELETE: another device needs to learn the day
            // was cleared, and a removed row is indistinguishable from one that
            // never synced (spec-13 §5).
            let row = ScoreRow(
                userId: operation.userId,
                day: operation.day,
                value: operation.value,
                reason: nil,
                mood: nil,
                clientUpdatedAt: operation.clientUpdatedAt,
                deletedAt: operation.clientUpdatedAt
            )
            try await client.send(try .upsert("scores", values: [row], onConflict: "user_id,day"))
        }
    }

    /// Pull rows changed since the last sync and merge them into the local store.
    private func pull(userId: UUID) async {
        let since = await queue.lastSyncedAt
        var filters: [String: String] = ["user_id": SupabaseRequest.eq(userId.uuidString.lowercased())]
        if let since {
            filters["client_updated_at"] = "gt.\(ISO8601DateFormatter().string(from: since))"
        }

        // Pull starts now, but stamp the watermark from *before* the request so a
        // row written while it was in flight is picked up next time instead of
        // being skipped.
        let startedAt = Date()

        do {
            let rows: [ScoreRow] = try await client.send(
                .select("scores", filters: filters, order: "client_updated_at.asc"),
                as: [ScoreRow].self
            )
            for row in rows {
                await merge(row, userId: userId)
            }
            await queue.markSynced(at: startedAt)
        } catch {
            // Silent by design (spec-13 §5).
            #if DEBUG
            print("[Scoor] sync pull failed: \(error.localizedDescription)")
            #endif
        }
    }

    /// Apply one server row locally, unless a pending local write for the same day
    /// is newer — that write hasn't uploaded yet, so the server copy is stale and
    /// applying it would silently revert what the user just typed.
    private func merge(_ row: ScoreRow, userId: UUID) async {
        guard let day = ScoreSyncFormat.date(fromDay: row.day, calendar: calendar) else { return }

        let queued = await queue.operations.first { $0.userId == userId && $0.day == row.day }
        if let queued, queued.clientUpdatedAt >= row.clientUpdatedAt { return }

        let existing = await local.getScoresForDate(userId: userId, date: day)

        if row.deletedAt != nil {
            for score in existing {
                try? await local.deleteScore(score)
            }
            return
        }

        let score = Score(
            id: existing.first?.id ?? UUID(),
            userId: userId,
            value: row.value,
            reason: row.reason,
            mood: row.mood.flatMap(Mood.init(rawValue:)),
            date: day,
            createdAt: existing.first?.createdAt ?? row.clientUpdatedAt
        )
        // saveScore already replaces the day's record, so this is an upsert.
        try? await local.saveScore(score)
    }
}

// MARK: - Wire model

/// Mirrors `public.scores`. Snake_case keys are PostgREST's column names.
struct ScoreRow: Codable, Equatable {
    let userId: UUID
    let day: String
    let value: Int
    let reason: String?
    let mood: String?
    let clientUpdatedAt: Date
    let deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case day
        case value
        case reason
        case mood
        case clientUpdatedAt = "client_updated_at"
        case deletedAt = "deleted_at"
    }
}
