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
    /// 점수+사유 → 파생 감정 분석 시임. 기본값은 비활성화(런타임 무동작).
    private let moodAnalyzer: MoodAnalyzing
    /// 기록 직후 리마인더 연계용. 오늘 기록 완료 시 배너 정리/스케줄 동기화.
    private let notificationService: NotificationServiceProtocol
    private var currentUserId: UUID?

    let targetDate: Date
    private let maxReasonLength = 200

    init(
        scoreService: ScoreServiceProtocol,
        userService: UserServiceProtocol,
        moodAnalyzer: MoodAnalyzing = DisabledMoodAnalyzer(),
        notificationService: NotificationServiceProtocol = MockNotificationService(),
        targetDate: Date = Date()
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.moodAnalyzer = moodAnalyzer
        self.notificationService = notificationService
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
            print("[Scoor] ScoreInputViewModel.load target=\(targetDate) found value=\(existing.value) mood=\(existing.mood?.rawValue ?? "nil")")
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
            // Mood is a DERIVED field — the user does not set it here. Preserve any
            // previously derived/stored mood on the record across an edit.
            newScore = Score(
                id: existing.id,
                userId: userId,
                value: score,
                reason: finalReason,
                mood: existing.mood,
                date: date,
                locationId: existing.locationId,
                createdAt: existing.createdAt
            )
        } else {
            // New record: mood is left nil until future analysis derives it.
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

            // 파생 감정 연계: 기존 mood가 없을 때만 분석기에 위임하고, 신호가
            // 있으면 같은 레코드에 써넣는다. 기본 분석기(Disabled)는 nil을 돌려
            // 주므로 이 경로는 무동작 — 규칙기반/AI로 교체하면 자동 점등된다.
            if newScore.mood == nil,
               let derivedMood = await moodAnalyzer.analyze(score: newScore.value, reason: newScore.reason) {
                var withMood = newScore
                withMood.mood = derivedMood
                try? await scoreService.saveScore(withMood)
                todaysScore = withMood
            }

            // 리마인더 연계: 오늘 기록을 마쳤으면 전달된 배너 정리 + 스케줄 동기화.
            await notificationService.handleScoreLogged(on: date)

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
            feedbackMessage = String(localized: "Could not save. Try again.")
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
