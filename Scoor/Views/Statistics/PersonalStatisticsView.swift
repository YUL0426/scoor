import SwiftUI
import Charts

/// Rolling periods use only recorded days; missing days never count as zero.
struct PersonalStatsSnapshot {
    let days: Int
    let start: Date
    let end: Date
    let entries: [ScoreEntry]
    let previousEntries: [ScoreEntry]

    init(entriesByDay: [Date: ScoreEntry], days: Int, now: Date = Date(), calendar: Calendar = .current) {
        self.days = days
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: end)!
        self.end = end
        self.start = start
        let previousStart = calendar.date(byAdding: .day, value: -days, to: start)!
        entries = entriesByDay.values.filter { $0.calendarDay >= start && $0.calendarDay <= end }
            .sorted { $0.calendarDay < $1.calendarDay }
        previousEntries = entriesByDay.values.filter { $0.calendarDay >= previousStart && $0.calendarDay < start }
    }

    var average: Int? { Self.average(entries) }
    var delta: Int? {
        guard let average, let previous = Self.average(previousEntries) else { return nil }
        return average - previous
    }
    var best: ScoreEntry? { entries.max { $0.score < $1.score } }
    private static func average(_ entries: [ScoreEntry]) -> Int? {
        guard !entries.isEmpty else { return nil }
        return Int((Double(entries.reduce(0) { $0 + $1.score }) / Double(entries.count)).rounded())
    }
}

enum PersonalStatsPeriod: String, CaseIterable {
    case daily, weekly, monthly

    var label: String {
        switch self {
        case .daily: return String(localized: "일별")
        case .weekly: return String(localized: "주별")
        case .monthly: return String(localized: "월별")
        }
    }

    func buckets(entries: [Date: ScoreEntry], now: Date = Date(), calendar: Calendar = .current) -> [PersonalStatsBucket] {
        let component: Calendar.Component = self == .daily ? .day : self == .weekly ? .weekOfYear : .month
        let count = self == .daily ? 7 : self == .weekly ? 4 : 6
        let today = calendar.startOfDay(for: now)
        let currentStart = calendar.dateInterval(of: component, for: today)!.start
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate(self == .monthly ? "MMM" : "Md")
        return (0..<count).map { index in
            let start = calendar.date(byAdding: component, value: index - count + 1, to: currentStart)!
            let end = calendar.date(byAdding: component, value: 1, to: start)!
            let recorded = entries.values.filter { $0.calendarDay >= start && $0.calendarDay < end && $0.calendarDay <= today }
            let average = recorded.isEmpty ? nil : Double(recorded.reduce(0) { $0 + $1.score }) / Double(recorded.count)
            let label = self == .weekly
                ? formatter.string(from: start) + "\n–" + formatter.string(from: calendar.date(byAdding: .day, value: -1, to: end)!)
                : formatter.string(from: start)
            return PersonalStatsBucket(start: start, label: label, average: average)
        }
    }
}

struct PersonalStatsBucket: Identifiable {
    var id: Date { start }
    let start: Date
    let label: String
    let average: Double?
}

struct PersonalStatisticsView: View {
    @ObservedObject var viewModel: MyPageViewModel
    var onSelectDate: (Date) -> Void
    @State private var period: PersonalStatsPeriod = .daily
    private var buckets: [PersonalStatsBucket] { period.buckets(entries: viewModel.entriesByDay) }
    private var days: Int {
        Calendar.current.dateComponents([.day], from: buckets[0].start, to: Calendar.current.startOfDay(for: Date())).day! + 1
    }
    @State private var showCalendar = false

    private var snapshot: PersonalStatsSnapshot {
        PersonalStatsSnapshot(entriesByDay: viewModel.entriesByDay, days: days)
    }
    private var streak: Int {
        StreakService.currentStreak(entriesByDay: viewModel.entriesByDay, today: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("나의 하루 흐름")
                        .font(.system(size: 22, weight: .bold))
                    Text("기록한 날들이 보여주는 나의 리듬")
                        .font(.system(size: 12))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
                Spacer(minLength: 0)
                ShareLink(item: String(localized: "scoor · 최근 \(days)일\n평균 \(snapshot.average.map(String.init) ?? "—")점 · \(snapshot.entries.count)일 기록\nHow's your day? scoor!")) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                        .background(ScoorPalette.bgRaised, in: Circle())
                }
                .accessibilityLabel("통계 공유")
            }
            HStack(spacing: 4) {
                ForEach(PersonalStatsPeriod.allCases, id: \.self) { option in
                    Button { period = option } label: {
                        Text(option.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(period == option ? ScoorPalette.bgBase : ScoorPalette.inkSecondary)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(period == option ? ScoorPalette.inkPrimary : .clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats-period-\(option.rawValue)")
                    .accessibilityAddTraits(period == option ? .isSelected : [])
                }
            }
            .padding(4)
            .background(ScoorPalette.bgRaised, in: Capsule())

            trendCard
            recordingSummary
            if let best = snapshot.best { highlight(best) }

            DisclosureGroup(isExpanded: $showCalendar) {
                CalendarSectionView(
                    displayedMonth: $viewModel.displayedMonth,
                    entryForDate: { viewModel.entry(for: $0) },
                    previousMonth: { viewModel.previousMonth() },
                    nextMonth: { viewModel.nextMonth() },
                    onSelectDate: onSelectDate
                )
                .padding(.horizontal, -24)
                .padding(.top, 14)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Label("기록 달력", systemImage: "calendar")
                        .font(.system(size: 15, weight: .semibold))
                    Text("날짜별 기록을 확인하고 수정하세요")
                        .font(.system(size: 12))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
            }
            .tint(ScoorPalette.inkSecondary)
            .accessibilityIdentifier("stats-calendar-disclosure")
            .padding(18)
            .background(ScoorPalette.bgRaised, in: RoundedRectangle(cornerRadius: 20))
        }
        .foregroundStyle(ScoorPalette.inkPrimary)
        .padding(.horizontal, 20)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("평균 점수")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                    if let average = snapshot.average {
                        ScoreValueView(score: average, font: .system(size: 46, weight: .bold), color: ScoorPalette.inkPrimary, logoHeight: 34)
                    } else {
                        Text("—").font(.system(size: 46, weight: .bold))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(snapshot.start.formatted(.dateTime.month().day())) – \(snapshot.end.formatted(.dateTime.month().day()))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                    if let delta = snapshot.delta {
                        Text("이전 \(days)일 대비 \(delta > 0 ? "+" : "")\(delta)점")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ScoorPalette.accent)
                    } else {
                        Text("기록한 날 기준")
                            .font(.system(size: 11))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                    }
                }
            }
            if snapshot.entries.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(ScoorPalette.accent)
                    Text("아직 이 기간의 기록이 없어요")
                        .font(.system(size: 15, weight: .semibold))
                    Text("하루를 남기면 이곳에 흐름이 그려져요")
                        .font(.system(size: 12))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                    Button("오늘 기록하기") { onSelectDate(Date()) }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ScoorPalette.accent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, minHeight: 170)
            } else {
                Chart(buckets) { bucket in
                    if let average = bucket.average {
                        BarMark(x: .value("날짜", bucket.label), y: .value("평균 점수", average))
                            .foregroundStyle(ScoorPalette.accent.gradient)
                            .cornerRadius(4)
                        if average == 0 {
                            PointMark(x: .value("날짜", bucket.label), y: .value("평균 점수", 0))
                                .foregroundStyle(ScoorPalette.accent)
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXScale(domain: buckets.map(\.label))
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(ScoorPalette.hairline)
                        AxisValueLabel().foregroundStyle(ScoorPalette.inkTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: buckets.map(\.label)) { value in
                        AxisValueLabel {
                            Text(value.as(String.self) ?? "")
                                .font(.system(size: 10))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(ScoorPalette.inkTertiary)
                        }
                    }
                }
                .frame(height: 170)
                .accessibilityIdentifier("stats-trend-chart")
            }
            Text("기록하지 않은 날은 평균에 포함하지 않아요")
                .font(.system(size: 11))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [ScoorPalette.accent.opacity(0.10), ScoorPalette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ScoorPalette.hairline, lineWidth: 1))
    }

    private var recordingSummary: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("기록한 날").font(.system(size: 12)).foregroundStyle(ScoorPalette.inkSecondary)
                Text("\(snapshot.entries.count) / \(days)일").font(.system(size: 20, weight: .bold))
                ProgressView(value: Double(snapshot.entries.count), total: Double(days)).tint(ScoorPalette.accent)
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(ScoorPalette.hairline).frame(width: 1, height: 52)
            VStack(alignment: .leading, spacing: 8) {
                Text("현재 연속 기록").font(.system(size: 12)).foregroundStyle(ScoorPalette.inkSecondary)
                Label("\(streak)일", systemImage: "flame")
                    .font(.system(size: 20, weight: .bold))
                Text("나만의 속도로 이어가세요")
                    .font(.system(size: 11)).foregroundStyle(ScoorPalette.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }

    private func highlight(_ entry: ScoreEntry) -> some View {
        Button { onSelectDate(entry.calendarDay) } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .foregroundStyle(ScoorPalette.accent)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 5) {
                    Text("이 기간의 가장 높은 하루 · \(entry.score)점")
                        .font(.system(size: 14, weight: .semibold))
                    Text(entry.reason?.isEmpty == false ? entry.reason! : entry.calendarDay.formatted(.dateTime.month().day()))
                        .font(.system(size: 12))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12))
            }
            .padding(18)
            .background(ScoorPalette.bgRaised, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
