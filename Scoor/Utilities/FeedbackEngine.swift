//
//  FeedbackEngine.swift
//  Scoor
//
//  Generates contextual feedback messages after score submission.
//

import Foundation

enum FeedbackType {
    case positive
    case neutral
    case encouragement
}

struct FeedbackResult {
    let message: String
    let type: FeedbackType
}

enum FeedbackEngine {
    private static let calendar = Calendar.current

    static func generateFeedback(currentScore: Int, history: [Score]) -> FeedbackResult {
        let sorted = history.sorted { $0.date > $1.date }
        let withoutToday = sorted.filter { !calendar.isDateInToday($0.date) }

        // 1. First ever entry
        if withoutToday.isEmpty {
            return FeedbackResult(message: String(localized: "Welcome! Your Scoor journey begins today. 🎉"), type: .positive)
        }

        // 1b. Edge values — a flawless 100 / a rock-bottom 0 always get their own
        // moment, ahead of comparative copy.
        if currentScore >= 100 {
            return FeedbackResult(message: String(localized: "A flawless 100! Soak it in 💯"), type: .positive)
        }
        if currentScore <= 0 {
            return FeedbackResult(message: String(localized: "A zero day. Be gentle with yourself — tomorrow resets 🌱"), type: .encouragement)
        }

        // 1c. Consecutive-logging streak milestone (연속 기록 갱신). Celebrated only
        // on milestone days so it doesn't drown out the comparative feedback.
        let logged = loggingStreak(sorted)
        if Self.streakMilestones.contains(logged) {
            return FeedbackResult(message: String(localized: "\(logged) days in a row! Keep the streak alive 🔥"), type: .positive)
        }

        // 2. Same day last week
        if let lastWeekSameDay = sameDayLastWeek(from: sorted) {
            let diff = currentScore - lastWeekSameDay.value
            let pts = abs(diff)
            return FeedbackResult(
                message: diff >= 0 ? String(localized: "\(pts) points higher than last week!") : String(localized: "\(pts) points lower than last week!"),
                type: diff >= 0 ? .positive : .encouragement
            )
        }

        // 3. Monthly average
        let thisMonth = sorted.filter { calendar.isDate($0.date, equalTo: Date(), toGranularity: .month) }
        if thisMonth.count >= 2 {
            let avg = Double(thisMonth.map(\.value).reduce(0, +)) / Double(thisMonth.count)
            let diff = Double(currentScore) - avg
            let pts = Int(abs(diff).rounded())
            return FeedbackResult(
                message: diff >= 0 ? String(localized: "\(pts) points above your monthly average!") : String(localized: "\(pts) points below your monthly average!"),
                type: .neutral
            )
        }

        // 4. Upward streak (3+ days)
        if let streak = upwardStreak(sorted), streak >= 3 {
            return FeedbackResult(message: String(localized: "\(streak)-day upward streak! 🔥"), type: .positive)
        }

        // 5. Downward streak
        if let streak = downwardStreak(sorted), streak >= 3 {
            return FeedbackResult(
                message: String(localized: "You've been trending down for \(streak) days. Hang in there 💪"),
                type: .encouragement
            )
        }

        // 6. High score
        if currentScore >= 90 {
            return FeedbackResult(message: String(localized: "What an amazing day! 🌟"), type: .positive)
        }

        // 7. Low score
        if currentScore <= 10 {
            return FeedbackResult(message: String(localized: "Tough day. Tomorrow is a new start 🌅"), type: .encouragement)
        }

        // 8. Fallback
        return FeedbackResult(message: String(localized: "Score recorded! Keep tracking. 📝"), type: .neutral)
    }

    /// Logging-streak milestones worth a callout.
    private static let streakMilestones: Set<Int> = [3, 7, 14, 30, 50, 100, 200, 365]

    /// Count of consecutive calendar days (ending today) that have an entry.
    /// `sorted` is expected to already include today's just-saved score.
    private static func loggingStreak(_ sorted: [Score], today: Date = Date()) -> Int {
        let days = Set(sorted.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: today)
        while days.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private static func sameDayLastWeek(from sorted: [Score]) -> Score? {
        guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return nil }
        return sorted.first { calendar.isDate($0.date, inSameDayAs: oneWeekAgo) }
    }

    private static func upwardStreak(_ sorted: [Score]) -> Int? {
        var streak = 0
        var prev: Int?
        for s in sorted.prefix(30) {
            if let p = prev, s.value > p { streak += 1 } else { break }
            prev = s.value
        }
        return streak >= 2 ? streak + 1 : nil
    }

    private static func downwardStreak(_ sorted: [Score]) -> Int? {
        var streak = 0
        var prev: Int?
        for s in sorted.prefix(30) {
            if let p = prev, s.value < p { streak += 1 } else { break }
            prev = s.value
        }
        return streak >= 2 ? streak + 1 : nil
    }
}
