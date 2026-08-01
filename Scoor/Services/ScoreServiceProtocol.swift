//
//  ScoreServiceProtocol.swift
//  Scoor
//

import Foundation

protocol ScoreServiceProtocol {
    func saveScore(_ score: Score) async throws
    func getTodaysScore(userId: UUID) async -> Score?
    func getScoreHistory(userId: UUID, limit: Int) async -> [Score]
    func getScoresForDate(userId: UUID, date: Date) async -> [Score]
    func deleteScore(_ score: Score) async throws
    /// Remove every stored score (account deletion, P0-4).
    func deleteAllScores() async throws
    /// Move every record from one owner id to another, returning the rows that
    /// moved (already re-keyed).
    ///
    /// Signing in swaps the account id — a guest journals under a device-local
    /// UUID and then adopts the server's `auth.users.id`. Every screen queries by
    /// the *current* id, so without this the history is still on disk but invisible,
    /// which reads as data loss and never reaches the server (spec-13 §7).
    @discardableResult
    func reassignScores(from oldUserId: UUID, to newUserId: UUID) async throws -> [Score]
}
