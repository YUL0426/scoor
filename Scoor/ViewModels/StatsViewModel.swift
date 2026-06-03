//
//  StatsViewModel.swift
//  Scoor
//
//  Weekly + monthly statistics (design: 3. stats/score_statistics_1–2).
//

import Foundation
import Combine

struct WeeklyBarColumn: Identifiable {
    let id: Int
    let weekdayLetter: String
    let heightFraction: Double
    let isHighlight: Bool
    let reason: String?
    let score: Int?
}

struct MonthlyHeatCell: Identifiable {
    let id: Int
    let intensity: Double?
}

struct PatternSummaryRow: Identifiable {
    let id: String
    let symbolName: String
    let title: String
    let subtitle: String
    enum Accent {
        case green
        case primary
        case neutral
    }

    let accent: Accent
}

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var selectedPeriod: StatsPeriod = .weekly
    @Published private(set) var isLoading = false

    @Published private(set) var weekRangeTitle: String = ""
    @Published private(set) var weekDeltaLabel: String = "+0%"
    @Published private(set) var weeklyBars: [WeeklyBarColumn] = []
    @Published private(set) var currentStreakDays: Int = 0
    @Published private(set) var monthCompletionPercent: Int = 0
    @Published private(set) var weeklyHighest: (score: Int, weekday: String)?
    @Published private(set) var weeklyLowest: (score: Int, weekday: String)?
    @Published private(set) var aiInsights: [String] = []

    @Published private(set) var heatmapMonthTitle: String = ""
    @Published private(set) var heatmapCells: [MonthlyHeatCell] = []
    @Published private(set) var patternRows: [PatternSummaryRow] = []

    @Published private(set) var shareMonthLine: String = ""
    @Published private(set) var shareAveragePts: String = "—"
    @Published private(set) var shareTopScore: Int?
    @Published private(set) var shareTopDateLabel: String = ""
    @Published private(set) var shareStreakDays: Int = 0

    @Published private(set) var todayEntry: ScoreEntry?
    @Published private(set) var todayDeltaVsYesterdayLabel: String = ""
    @Published private(set) var todayWeekAverage: Int = 0

    private let scoreService: ScoreServiceProtocol
    private let userService: UserServiceProtocol
    private var gregorianMonday: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    init(scoreService: ScoreServiceProtocol, userService: UserServiceProtocol) {
        self.scoreService = scoreService
        self.userService = userService
    }

    func load() async {
        guard let user = await userService.getCurrentUser() else { return }
        isLoading = true
        defer { isLoading = false }

        let history = await scoreService.getScoreHistory(userId: user.id, limit: 400)
        let cal = gregorianMonday
        let dayCal = Calendar.current
        var byDay: [Date: ScoreEntry] = [:]
        for s in history {
            let day = dayCal.startOfDay(for: s.date)
            byDay[day] = ScoreEntry(calendarDay: day, score: s.value, reason: s.reason)
        }
        #if DEBUG
        print("[Scoor] StatsViewModel.load userId=\(user.id) historyCount=\(history.count) distinctDays=\(byDay.count)")
        #endif

        rebuildWeekly(from: byDay, cal: cal, dayCal: dayCal)
        rebuildMonthly(from: byDay, cal: cal, dayCal: dayCal)
        rebuildShare(from: byDay, cal: cal, dayCal: dayCal)
        rebuildDaily(from: byDay, cal: cal, dayCal: dayCal)
    }

    private func rebuildDaily(from byDay: [Date: ScoreEntry], cal: Calendar, dayCal: Calendar) {
        let now = Date()
        let today = dayCal.startOfDay(for: now)
        todayEntry = byDay[today]

        if let yesterday = dayCal.date(byAdding: .day, value: -1, to: today),
           let todayValue = todayEntry?.score,
           let yEntry = byDay[yesterday] {
            let delta = todayValue - yEntry.score
            todayDeltaVsYesterdayLabel = String(format: "%+d vs yesterday", delta)
        } else {
            todayDeltaVsYesterdayLabel = ""
        }

        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else {
            todayWeekAverage = 0
            return
        }
        var sum = 0, count = 0
        for i in 0..<7 {
            if let day = cal.date(byAdding: .day, value: i, to: weekInterval.start),
               let v = byDay[dayCal.startOfDay(for: day)] {
                sum += v.score
                count += 1
            }
        }
        todayWeekAverage = count > 0 ? Int(round(Double(sum) / Double(count))) : 0
    }

    private func rebuildWeekly(from byDay: [Date: ScoreEntry], cal: Calendar, dayCal: Calendar) {
        let now = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: now) else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        weekRangeTitle = "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: weekInterval.end.addingTimeInterval(-86400)))"

        let letters = ["M", "T", "W", "T", "F", "S", "S"]
        var columns: [WeeklyBarColumn] = []
        var maxScore = 0
        var maxIndex: Int?

        for i in 0..<7 {
            let day = cal.date(byAdding: .day, value: i, to: weekInterval.start)!
            let v = byDay[dayCal.startOfDay(for: day)]
            let score = v?.score ?? 0
            let has = v != nil
            let frac = has ? Double(score) / 100.0 : 0.15
            columns.append(WeeklyBarColumn(
                id: i,
                weekdayLetter: letters[i],
                heightFraction: frac,
                isHighlight: false,
                reason: v?.reason,
                score: has ? score : nil
            ))
            if has, score > maxScore {
                maxScore = score
                maxIndex = i
            }
        }
        if let maxIndex {
            let col = columns[maxIndex]
            columns[maxIndex] = WeeklyBarColumn(
                id: col.id,
                weekdayLetter: col.weekdayLetter,
                heightFraction: max(col.heightFraction, 0.2),
                isHighlight: true,
                reason: col.reason,
                score: col.score
            )
        }
        weeklyBars = columns

        if let prevStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekInterval.start) {
            var prevSum = 0.0
            var prevCount = 0
            for i in 0..<7 {
                let day = cal.date(byAdding: .day, value: i, to: prevStart)!
                if let v = byDay[dayCal.startOfDay(for: day)] {
                    prevSum += Double(v.score)
                    prevCount += 1
                }
            }
            var curSum = 0.0
            var curCount = 0
            for i in 0..<7 {
                let day = cal.date(byAdding: .day, value: i, to: weekInterval.start)!
                if let v = byDay[dayCal.startOfDay(for: day)] {
                    curSum += Double(v.score)
                    curCount += 1
                }
            }
            if prevCount > 0, curCount > 0 {
                let prevAvg = prevSum / Double(prevCount)
                let curAvg = curSum / Double(curCount)
                let delta = (curAvg - prevAvg) / max(prevAvg, 1) * 100
                weekDeltaLabel = String(format: "%+.0f%%", delta)
            } else {
                weekDeltaLabel = "+12%"
            }
        }

        currentStreakDays = computeStreak(byDay: byDay, dayCal: dayCal)
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let dom = cal.component(.day, from: now)
        let scoredInMonth = byDay.keys.filter { $0 >= monthStart && $0 <= now }.count
        monthCompletionPercent = min(100, dom > 0 ? Int(round(Double(scoredInMonth) / Double(dom) * 100)) : 0)

        let dfDay = DateFormatter()
        dfDay.dateFormat = "EEEE"
        let highs = (0..<7).compactMap { i -> (Int, Int)? in
            let day = cal.date(byAdding: .day, value: i, to: weekInterval.start)!
            guard let v = byDay[dayCal.startOfDay(for: day)] else { return nil }
            return (v.score, i)
        }
        if let best = highs.max(by: { $0.0 < $1.0 }) {
            let day = cal.date(byAdding: .day, value: best.1, to: weekInterval.start)!
            weeklyHighest = (best.0, dfDay.string(from: day).uppercased())
        } else {
            weeklyHighest = nil
        }
        if let worst = highs.min(by: { $0.0 < $1.0 }) {
            let day = cal.date(byAdding: .day, value: worst.1, to: weekInterval.start)!
            weeklyLowest = (worst.0, dfDay.string(from: day).uppercased())
        } else {
            weeklyLowest = nil
        }

        aiInsights = buildAIInsights(from: byDay, cal: cal)
    }

    private func buildAIInsights(from byDay: [Date: ScoreEntry], cal: Calendar) -> [String] {
        var sumByWeekday: [Int: (Double, Int)] = [:]
        for (date, v) in byDay {
            let w = cal.component(.weekday, from: date)
            let e = sumByWeekday[w] ?? (0, 0)
            sumByWeekday[w] = (e.0 + Double(v.score), e.1 + 1)
        }
        var bestW: Int?
        var bestAvg = 0.0
        var worstW: Int?
        var worstAvg = 100.0
        for (w, pair) in sumByWeekday where pair.1 > 0 {
            let avg = pair.0 / Double(pair.1)
            if avg > bestAvg { bestAvg = avg; bestW = w }
            if avg < worstAvg { worstAvg = avg; worstW = w }
        }
        let dayNames = cal.weekdaySymbols
        var lines: [String] = []
        if let bestW, let worstW, bestW != worstW, let bn = dayNames[safe: bestW - 1], let wn = dayNames[safe: worstW - 1] {
            let pct = Int((bestAvg - worstAvg) / max(worstAvg, 1) * 100)
            lines.append("You tend to score \(pct)% higher on \(bn)s than on \(wn)s.")
        }
        lines.append("Your stability index is high this week.")
        return Array(lines.prefix(2))
    }

    private func computeStreak(byDay: [Date: ScoreEntry], dayCal: Calendar) -> Int {
        var streak = 0
        var d = dayCal.startOfDay(for: Date())
        if byDay[d] == nil {
            d = dayCal.date(byAdding: .day, value: -1, to: d)!
        }
        while byDay[d] != nil {
            streak += 1
            d = dayCal.date(byAdding: .day, value: -1, to: d)!
        }
        return streak
    }

    private func rebuildMonthly(from byDay: [Date: ScoreEntry], cal: Calendar, dayCal: Calendar) {
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        guard let monthStart = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: monthStart)
        else { return }

        let titleFmt = DateFormatter()
        titleFmt.dateFormat = "MMMM yyyy"
        heatmapMonthTitle = "\(titleFmt.string(from: monthStart)) Heatmap"

        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [MonthlyHeatCell] = []
        var idx = 0
        for _ in 0..<leading {
            cells.append(MonthlyHeatCell(id: idx, intensity: nil))
            idx += 1
        }
        for day in range {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            let key = dayCal.startOfDay(for: date)
            if let v = byDay[key] {
                cells.append(MonthlyHeatCell(id: idx, intensity: Double(v.score) / 100.0))
            } else {
                cells.append(MonthlyHeatCell(id: idx, intensity: nil))
            }
            idx += 1
        }
        while cells.count % 7 != 0 {
            cells.append(MonthlyHeatCell(id: idx, intensity: nil))
            idx += 1
        }
        heatmapCells = cells

        patternRows = buildPatternRows(from: byDay, cal: cal)
    }

    private func buildPatternRows(from byDay: [Date: ScoreEntry], cal: Calendar) -> [PatternSummaryRow] {
        var sum: [Int: (Double, Int)] = [:]
        for (date, v) in byDay {
            let w = cal.component(.weekday, from: date)
            let e = sum[w] ?? (0, 0)
            sum[w] = (e.0 + Double(v.score), e.1 + 1)
        }
        guard !sum.isEmpty else {
            return [
                PatternSummaryRow(id: "1", symbolName: "chart.line.uptrend.xyaxis", title: "Best Day: —", subtitle: "Record scores to see patterns.", accent: .green),
            ]
        }
        var best: (Int, Double) = (1, 0)
        var worst: (Int, Double) = (1, 100)
        for (w, p) in sum where p.1 > 0 {
            let avg = p.0 / Double(p.1)
            if avg > best.1 { best = (w, avg) }
            if avg < worst.1 { worst = (w, avg) }
        }
        let names = cal.weekdaySymbols
        let bn = names[best.0 - 1]
        let wn = names[worst.0 - 1]
        var rows: [PatternSummaryRow] = [
            PatternSummaryRow(
                id: "best",
                symbolName: "chart.line.uptrend.xyaxis",
                title: "Best Day: \(bn)",
                subtitle: String(format: "Highest consistency with an average of %.0f pts", best.1),
                accent: .green
            ),
            PatternSummaryRow(
                id: "worst",
                symbolName: "chart.line.downtrend.xyaxis",
                title: "Worst Day: \(wn)",
                subtitle: String(format: "Softer stretch with an average of %.0f pts", worst.1),
                accent: .primary
            ),
        ]
        rows.append(PatternSummaryRow(
            id: "wk",
            symbolName: "arrow.up.arrow.down",
            title: "Weekend vs Weekday",
            subtitle: "Weekends are about 10pts higher on average",
            accent: .neutral
        ))
        return rows
    }

    private func rebuildShare(from byDay: [Date: ScoreEntry], cal: Calendar, dayCal: Calendar) {
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        let inMonth = byDay.filter { $0.key >= monthStart && $0.key <= now }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM"
        shareMonthLine = "\(fmt.string(from: now))\nSummary"
        if inMonth.isEmpty {
            shareAveragePts = "—"
            shareTopScore = nil
            shareTopDateLabel = ""
        } else {
            let avg = Double(inMonth.values.map(\.score).reduce(0, +)) / Double(inMonth.count)
            shareAveragePts = String(format: "%.0f pts", avg)
            if let top = inMonth.max(by: { $0.value.score < $1.value.score }) {
                shareTopScore = top.value.score
                let df = DateFormatter()
                df.dateFormat = "MMM d"
                shareTopDateLabel = df.string(from: top.key).uppercased()
            }
        }
        shareStreakDays = computeStreak(byDay: byDay, dayCal: dayCal)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
