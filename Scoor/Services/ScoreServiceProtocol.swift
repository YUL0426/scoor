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
}
