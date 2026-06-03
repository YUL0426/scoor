//
//  ScoreInputViewModel.swift
//  Scoor
//

import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class ScoreInputViewModel: ObservableObject {
    @Published var score: Int
    @Published var reason: String
    @Published var isSubmitting = false
    @Published var isSubmitted = false
    @Published var feedbackMessage: String?
    @Published var feedbackType: FeedbackType = .neutral
    @Published var todaysScore: Score?

    private let scoreService: ScoreServiceProtocol
    private let userService: UserServiceProtocol
    private var currentUserId: UUID?

    let targetDate: Date
    private let maxReasonLength = 200

    init(scoreService: ScoreServiceProtocol, userService: UserServiceProtocol, targetDate: Date = Date()) {
        self.scoreService = scoreService
        self.userService = userService
        self.targetDate = Calendar.current.startOfDay(for: targetDate)
        self.score = 0
        self.reason = ""
    }

    var reasonCount: Int { reason.count }
    var canSubmit: Bool { !isSubmitting }
    var isUpdateMode: Bool { todaysScore != nil }
    var isTargetToday: Bool { Calendar.current.isDateInToday(targetDate) }

    func loadTodaysScore() async {
        guard let user = await userService.getCurrentUser() else { return }
        currentUserId = user.id

        let existing: Score?
        if isTargetToday {
            existing = await scoreService.getTodaysScore(userId: user.id)
        } else {
            let history = await scoreService.getScoreHistory(userId: user.id, limit: 365)
            let cal = Calendar.current
            existing = history.first { cal.isDate($0.date, inSameDayAs: targetDate) }
        }

        if let existing = existing {
            todaysScore = existing
            score = existing.value
            reason = existing.reason ?? ""
            #if DEBUG
            print("[Scoor] ScoreInputViewModel.load target=\(targetDate) found value=\(existing.value)")
            #endif
        } else {
            todaysScore = nil
            score = 0
            reason = ""
            #if DEBUG
            print("[Scoor] ScoreInputViewModel.load target=\(targetDate) none")
            #endif
        }
    }

    func submitScore() async {
        guard let userId = currentUserId else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReason = trimmedReason.isEmpty ? nil : String(trimmedReason.prefix(maxReasonLength))
        let date = targetDate

        let newScore: Score
        if let existing = todaysScore {
            newScore = Score(
                id: existing.id,
                userId: userId,
                value: score,
                reason: finalReason,
                date: date,
                locationId: existing.locationId,
                createdAt: existing.createdAt
            )
        } else {
            newScore = Score(
                userId: userId,
                value: score,
                reason: finalReason,
                date: date
            )
        }

        do {
            try await scoreService.saveScore(newScore)
            todaysScore = newScore
            #if DEBUG
            print("[Scoor] ScoreInputViewModel.submitScore saved value=\(newScore.value) day=\(newScore.date)")
            #endif

            let history = await scoreService.getScoreHistory(userId: userId, limit: 90)
            let result = FeedbackEngine.generateFeedback(currentScore: score, history: history)
            feedbackMessage = result.message
            feedbackType = result.type
            isSubmitted = true

            #if canImport(UIKit)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            #endif
        } catch {
            feedbackMessage = "Could not save. Try again."
            feedbackType = .encouragement
        }
    }

    func updateScore(_ value: Int) {
        score = min(100, max(0, value))
    }

    func setReason(_ text: String) {
        reason = String(text.prefix(maxReasonLength))
    }

    func clearFeedback() {
        feedbackMessage = nil
    }

    /// After the completion step, return to the guided flow while keeping saved data loaded.
    func prepareForNextFlowInteraction() {
        isSubmitted = false
        clearFeedback()
    }
}
