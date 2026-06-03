//
//  HomeViewModel.swift
//  Scoor
//
//  Aggregates everything the emotional Home screen needs:
//  today's entry, AI-style insights, a global "live feeling" feed,
//  recent emotional history, and a streak / life-flow summary.
//
//  Mood-first: numbers are inputs; the output is *atmosphere*.
//

import Foundation
import Combine

// MARK: - Display value types

struct HomeInsight: Identifiable, Hashable {
    let id: String
    let icon: String
    let text: String
    let tint: Tint

    enum Tint: Hashable { case primary, soft, neutral }
}

struct LiveFeedItem: Identifiable, Hashable {
    let id: String
    let icon: String
    let text: String
}

struct HomeRecentRow: Identifiable, Hashable {
    let id: String
    let score: Int
    let reason: String
    let relativeLabel: String
    let dayLabel: String
    /// The calendar day this entry belongs to — used to open the edit sheet for that day.
    let date: Date
}

enum EmotionalFlow: String {
    case rising = "Your emotional flow is improving"
    case steady = "You're holding a calm rhythm"
    case dipping = "A softer stretch — be gentle with yourself"
    case starting = "A new chapter is starting"
}

// MARK: - View model

@MainActor
final class HomeViewModel: ObservableObject {
    // Hero
    @Published private(set) var todayEntry: ScoreEntry?
    @Published private(set) var todayMoodPhrase: String = ""
    @Published private(set) var todaySubMessage: String = ""
    @Published private(set) var todayDateLine: String = ""

    // Week pulse (hero slide 2)
    @Published private(set) var weekScores: [Int?] = []
    @Published private(set) var weekAverage: Int = 0

    // Emotional flow (hero slide 3)
    @Published private(set) var emotionalFlow: EmotionalFlow = .starting

    // AI insights
    @Published private(set) var insights: [HomeInsight] = []

    // Live feed
    @Published private(set) var liveFeed: [LiveFeedItem] = []

    // Recent history
    @Published private(set) var recent: [HomeRecentRow] = []

    // Streak / life-flow strip
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var monthlyAverage: Int = 0
    @Published private(set) var happiestWeekday: String = ""

    @Published private(set) var isLoading = false

    private let scoreService: ScoreServiceProtocol
    private let userService: UserServiceProtocol
    private let now: () -> Date

    init(
        scoreService: ScoreServiceProtocol,
        userService: UserServiceProtocol,
        now: @escaping () -> Date = Date.init
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.now = now
        self.todayDateLine = Self.dateLine(for: now())
        self.liveFeed = Self.seedLiveFeed
    }

    var todayScore: Int? { todayEntry?.score }
    var hasTodayEntry: Bool { todayEntry != nil }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let user = await userService.getCurrentUser() else { return }
        let history = await scoreService.getScoreHistory(userId: user.id, limit: 120)

        let cal = Calendar.current
        let today = cal.startOfDay(for: now())

        // Index by day (last-write-wins per day).
        var byDay: [Date: ScoreEntry] = [:]
        for s in history {
            let key = cal.startOfDay(for: s.date)
            byDay[key] = ScoreEntry(calendarDay: key, score: s.value, reason: s.reason)
        }

        // Hero — today
        todayEntry = byDay[today]
        todayDateLine = Self.dateLine(for: now())

        // Week (Mon-anchored) scores
        var mondayCal = cal
        mondayCal.firstWeekday = 2
        let weekInterval = mondayCal.dateInterval(of: .weekOfYear, for: now())
        var week: [Int?] = Array(repeating: nil, count: 7)
        var weekSum = 0
        var weekCount = 0
        if let start = weekInterval?.start {
            for i in 0..<7 {
                if let d = mondayCal.date(byAdding: .day, value: i, to: start) {
                    let v = byDay[cal.startOfDay(for: d)]?.score
                    week[i] = v
                    if let v = v { weekSum += v; weekCount += 1 }
                }
            }
        }
        weekScores = week
        weekAverage = weekCount > 0 ? Int(round(Double(weekSum) / Double(weekCount))) : 0

        // Mood phrase & sub-message
        todayMoodPhrase = MoodCopy.phrase(for: todayEntry?.score)
        todaySubMessage = MoodCopy.subMessage(today: todayEntry?.score, weekAverage: weekAverage)

        // Streak
        streakDays = Self.computeStreak(byDay: byDay, anchor: today, cal: cal)

        // Monthly average
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        let monthEntries = byDay.filter { $0.key >= monthStart && $0.key <= today }
        if !monthEntries.isEmpty {
            let sum = monthEntries.values.map(\.score).reduce(0, +)
            monthlyAverage = Int(round(Double(sum) / Double(monthEntries.count)))
        } else {
            monthlyAverage = 0
        }

        // Happiest weekday
        happiestWeekday = Self.computeHappiestWeekday(byDay: byDay, cal: cal)

        // Emotional flow (last 14 days trend)
        emotionalFlow = Self.computeFlow(byDay: byDay, today: today, cal: cal)

        // AI insights
        insights = Self.buildInsights(
            byDay: byDay,
            today: today,
            todayEntry: todayEntry,
            weekAverage: weekAverage,
            cal: cal
        )

        // Recent history (last 4, excluding today)
        recent = Self.buildRecent(history: history, excluding: today, cal: cal)
    }

    // MARK: - Helpers

    private static func dateLine(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date).uppercased()
    }

    private static func computeStreak(byDay: [Date: ScoreEntry], anchor: Date, cal: Calendar) -> Int {
        var streak = 0
        var d = anchor
        if byDay[d] == nil {
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        while byDay[d] != nil {
            streak += 1
            d = cal.date(byAdding: .day, value: -1, to: d) ?? d
        }
        return streak
    }

    private static func computeHappiestWeekday(byDay: [Date: ScoreEntry], cal: Calendar) -> String {
        guard !byDay.isEmpty else { return "" }
        var sums: [Int: (total: Double, count: Int)] = [:]
        for (date, entry) in byDay {
            let w = cal.component(.weekday, from: date)
            let cur = sums[w] ?? (0, 0)
            sums[w] = (cur.total + Double(entry.score), cur.count + 1)
        }
        guard let best = sums
            .filter({ $0.value.count > 0 })
            .map({ ($0.key, $0.value.total / Double($0.value.count)) })
            .max(by: { $0.1 < $1.1 })
        else { return "" }
        return cal.weekdaySymbols[safe: best.0 - 1] ?? ""
    }

    private static func computeFlow(byDay: [Date: ScoreEntry], today: Date, cal: Calendar) -> EmotionalFlow {
        guard byDay.count >= 3 else { return .starting }
        let recentRange = stride(from: 0, to: 7, by: 1).compactMap { offset -> Int? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDay[d]?.score
        }
        let priorRange = stride(from: 7, to: 14, by: 1).compactMap { offset -> Int? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDay[d]?.score
        }
        guard !recentRange.isEmpty, !priorRange.isEmpty else { return .starting }
        let recentAvg = Double(recentRange.reduce(0, +)) / Double(recentRange.count)
        let priorAvg = Double(priorRange.reduce(0, +)) / Double(priorRange.count)
        let delta = recentAvg - priorAvg
        if delta >= 5 { return .rising }
        if delta <= -5 { return .dipping }
        return .steady
    }

    private static func buildInsights(
        byDay: [Date: ScoreEntry],
        today: Date,
        todayEntry: ScoreEntry?,
        weekAverage: Int,
        cal: Calendar
    ) -> [HomeInsight] {
        var insights: [HomeInsight] = []

        // 1. vs last week's average
        if let t = todayEntry?.score, weekAverage > 0 {
            let delta = t - weekAverage
            if abs(delta) >= 3 {
                let phrase = delta > 0
                    ? "\(delta) points higher than this week's average"
                    : "\(abs(delta)) points softer than this week's average"
                insights.append(HomeInsight(id: "vs-week", icon: "chart.line.uptrend.xyaxis", text: phrase, tint: .primary))
            }
        }

        // 2. Reason keyword that appears often in last 7 days
        let last7Reasons = stride(from: 0, to: 7, by: 1).compactMap { offset -> String? in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return byDay[d]?.reason
        }.joined(separator: " ").lowercased()
        let keywordHits = MoodCopy.commonKeywords.compactMap { keyword -> (String, Int)? in
            let count = last7Reasons.components(separatedBy: keyword).count - 1
            return count >= 2 ? (keyword, count) : nil
        }
        if let top = keywordHits.max(by: { $0.1 < $1.1 }) {
            insights.append(HomeInsight(
                id: "keyword-\(top.0)",
                icon: "sparkle",
                text: "\"\(top.0)\" appears often in the last 7 days",
                tint: .soft
            ))
        }

        // 3. Best weekday pattern
        var sumByWeekday: [Int: (Double, Int)] = [:]
        for (date, e) in byDay {
            let w = cal.component(.weekday, from: date)
            let cur = sumByWeekday[w] ?? (0, 0)
            sumByWeekday[w] = (cur.0 + Double(e.score), cur.1 + 1)
        }
        if let best = sumByWeekday
            .filter({ $0.value.1 >= 2 })
            .map({ ($0.key, $0.value.0 / Double($0.value.1)) })
            .max(by: { $0.1 < $1.1 }),
           let name = cal.weekdaySymbols[safe: best.0 - 1]
        {
            insights.append(HomeInsight(
                id: "best-weekday",
                icon: "calendar.badge.checkmark",
                text: "\(name)s tend to be your highest-scoring days",
                tint: .neutral
            ))
        }

        // 4. Highest score this month (if not already in list)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        let monthEntries = byDay.filter { $0.key >= monthStart && $0.key <= today }
        if let topMonth = monthEntries.values.map(\.score).max(), topMonth >= 80 {
            insights.append(HomeInsight(
                id: "top-month",
                icon: "star.circle.fill",
                text: "Your highest score this month is \(topMonth)",
                tint: .primary
            ))
        }

        // Fallback if a fresh user has no data
        if insights.isEmpty {
            insights = [
                HomeInsight(id: "fresh-1", icon: "sparkle", text: "Record a few days — your patterns will appear here", tint: .soft),
                HomeInsight(id: "fresh-2", icon: "leaf", text: "Scoor learns the rhythm of your days quietly", tint: .neutral),
            ]
        }

        return Array(insights.prefix(3))
    }

    private static func buildRecent(history: [Score], excluding today: Date, cal: Calendar) -> [HomeRecentRow] {
        let sorted = history.sorted(by: { $0.date > $1.date })
        var rows: [HomeRecentRow] = []
        for s in sorted {
            let day = cal.startOfDay(for: s.date)
            if day == today { continue }
            let reason = (s.reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let display = reason.isEmpty ? "No note for this day" : reason
            rows.append(HomeRecentRow(
                id: s.id.uuidString,
                score: s.value,
                reason: display,
                relativeLabel: Self.relative(s.date, now: Date()),
                dayLabel: Self.shortDay(s.date),
                date: day
            ))
            if rows.count >= 4 { break }
        }
        return rows
    }

    private static func relative(_ date: Date, now: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: now)
    }

    private static func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }

    // MARK: - Live feed (mock for v1; backend stream later)

    private static let seedLiveFeed: [LiveFeedItem] = [
        LiveFeedItem(id: "lf-seoul", icon: "wave.3.right", text: "Average Scoor in Seoul right now: 7.4"),
        LiveFeedItem(id: "lf-tokyo", icon: "sparkles", text: "Someone in Tokyo just recorded a 92"),
        LiveFeedItem(id: "lf-osaka", icon: "sun.max", text: "Today's happiest city: Osaka"),
        LiveFeedItem(id: "lf-live", icon: "dot.radiowaves.left.and.right", text: "12 people are recording their day right now"),
        LiveFeedItem(id: "lf-london", icon: "cloud.moon", text: "London is feeling 6.8 this evening"),
        LiveFeedItem(id: "lf-asia", icon: "globe.asia.australia", text: "Mood across Asia leans warm tonight"),
    ]
}

// MARK: - Mood copy / palette helpers

enum MoodCopy {
    static func phrase(for score: Int?) -> String {
        guard let score = score else { return "How was today?" }
        switch score {
        case 90...: return "An incredible day."
        case 80..<90: return "Today felt better than expected."
        case 70..<80: return "A bright, steady day."
        case 60..<70: return "Warm and solid."
        case 50..<60: return "An ordinary day worth keeping."
        case 40..<50: return "A heavier afternoon."
        case 25..<40: return "Soft pace — take it slow."
        default: return "Be gentle with yourself tonight."
        }
    }

    static func subMessage(today: Int?, weekAverage: Int) -> String {
        guard let today = today else { return "Tap + when you're ready to record." }
        guard weekAverage > 0 else { return "First entry of your week." }
        let delta = today - weekAverage
        if delta >= 8 { return "+\(delta) above your week so far" }
        if delta <= -8 { return "\(delta) softer than your week so far" }
        return "In rhythm with your week"
    }

    static let commonKeywords: [String] = [
        "sleep", "tired", "work", "family", "friend", "run",
        "exercise", "food", "rain", "sun", "stress", "music",
        "walk", "rest", "meeting", "study", "home", "trip",
    ]
}

// MARK: - Mood palette (drives Hero gradient)

enum MoodPalette {
    static func gradient(for score: Int?) -> [String] {
        guard let score = score else { return ["#F8F5F5", "#EFEAEA"] }
        switch score {
        case 90...: return ["#FF6B6B", "#F42525"]
        case 80..<90: return ["#FF9B83", "#FF5252"]
        case 70..<80: return ["#FFB199", "#FF7575"]
        case 60..<70: return ["#FFD3B0", "#FF9F87"]
        case 50..<60: return ["#FFE4C4", "#E8B58F"]
        case 40..<50: return ["#E8D3C0", "#BFA189"]
        case 25..<40: return ["#C7D1E0", "#8B9DAF"]
        default: return ["#A8B5C5", "#6F7E91"]
        }
    }

    static func glyphTint(for score: Int?) -> String {
        guard let score = score else { return "#F42525" }
        return score >= 70 ? "#FFFFFF" : "#FFFFFF"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
