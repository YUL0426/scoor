//
//  StatsView.swift
//  Scoor
//
//  Weekly + monthly statistics (design: 3. stats/score_statistics_1–2, share modal).
//

import SwiftUI

struct StatsView: View {
    @StateObject private var viewModel: StatsViewModel
    @State private var showShareSheet = false

    init(scoreService: ScoreServiceProtocol, userService: UserServiceProtocol) {
        _viewModel = StateObject(wrappedValue: StatsViewModel(scoreService: scoreService, userService: userService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                statsHeader
                periodPicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .onChange(of: viewModel.selectedPeriod) { _, _ in
                        Task { await viewModel.load() }
                    }

                if viewModel.isLoading {
                    ProgressView().padding(.vertical, 48)
                } else {
                    switch viewModel.selectedPeriod {
                    case .daily: dailyContent
                    case .weekly: weeklyContent
                    case .monthly: monthlyContent
                    }
                }
            }
            .padding(.bottom, 48)
        }
        .background(Color(red: 0.97, green: 0.98, blue: 0.99))
        .navigationBarHidden(true)
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .scoorScoreStoreDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showShareSheet) {
            InstagramStoryShareSheet(viewModel: viewModel, onDismiss: { showShareSheet = false })
        }
    }

    private var statsHeader: some View {
        HStack(alignment: .center) {
            Text(viewModel.selectedPeriod.headerTitle)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color.primary)
            Spacer()
            Image(systemName: viewModel.selectedPeriod == .monthly ? "calendar.badge.clock" : "calendar")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
                .frame(width: 40, height: 40)
                .background(Color(red: 0.95, green: 0.96, blue: 0.97))
                .clipShape(Circle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    private var periodPicker: some View {
        HStack(spacing: 4) {
            ForEach(StatsPeriod.allCases, id: \.self) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedPeriod = period
                    }
                } label: {
                    Text(period.label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(viewModel.selectedPeriod == period ? DesignTokens.primaryColor : Color(red: 0.55, green: 0.58, blue: 0.62))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedPeriod == period ? Color.white : Color.clear)
                                .shadow(color: viewModel.selectedPeriod == period ? .black.opacity(0.06) : .clear, radius: 2, x: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.95, green: 0.96, blue: 0.97))
        .clipShape(Capsule())
    }

    // MARK: - Daily

    private var dailyContent: some View {
        VStack(spacing: 20) {
            todayCard
                .padding(.horizontal, 24)
            HStack(spacing: 12) {
                streakMiniCard
                weekAvgMiniCard
            }
            .padding(.horizontal, 24)
        }
    }

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S SCORE")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                        .tracking(1.2)
                    Text(todayDateLine)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                if !viewModel.todayDeltaVsYesterdayLabel.isEmpty {
                    Text(viewModel.todayDeltaVsYesterdayLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DesignTokens.primaryColor.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            if let entry = viewModel.todayEntry {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(entry.score)")
                        .font(.system(size: 88, weight: .heavy))
                        .italic()
                        .foregroundStyle(DesignTokens.primaryColor)
                    Text("/100")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                }
                if let reason = entry.reason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(reason)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 0.2, green: 0.22, blue: 0.28))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignTokens.primaryColor.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(DesignTokens.primaryColor.opacity(0.6))
                    Text("No score yet for today")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                    Text("Tap the + button to add today's entry")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.65, green: 0.68, blue: 0.72))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private var weekAvgMiniCard: some View {
        HStack(spacing: 12) {
            ConicRingProgressView(progress: Double(viewModel.todayWeekAverage) / 100, label: "\(viewModel.todayWeekAverage)")
            VStack(alignment: .leading, spacing: 4) {
                Text("WEEK AVERAGE")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                Text("\(viewModel.todayWeekAverage) pts")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private var todayDateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM d"
        return f.string(from: Date())
    }

    // MARK: - Weekly (statistics_1)

    private var weeklyContent: some View {
        VStack(spacing: 20) {
            weeklyChartCard
            HStack(spacing: 12) {
                streakMiniCard
                monthCompletionMiniCard
            }
            .padding(.horizontal, 24)
            HStack(spacing: 16) {
                if let h = viewModel.weeklyHighest {
                    statTile(title: "Highest Day", value: "\(h.score)", suffix: "/100", caption: h.weekday)
                } else {
                    statTile(title: "Highest Day", value: "—", suffix: "", caption: "—")
                }
                if let l = viewModel.weeklyLowest {
                    statLowTile(title: "Lowest Day", value: "\(l.score)", suffix: "/100", caption: l.weekday)
                } else {
                    statLowTile(title: "Lowest Day", value: "—", suffix: "", caption: "—")
                }
            }
            .padding(.horizontal, 24)
            aiInsightCard
                .padding(.horizontal, 24)
        }
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEEKLY PERFORMANCE")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                        .tracking(1.2)
                    Text(viewModel.weekRangeTitle)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
                Text(viewModel.weekDeltaLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
            }

            WeeklyBarChartView(columns: viewModel.weeklyBars)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 24)
    }

    private var streakMiniCard: some View {
        HStack(spacing: 12) {
            ConicRingProgressView(progress: min(1, Double(viewModel.currentStreakDays) / 7), label: "\(viewModel.currentStreakDays)d")
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT STREAK")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                Text("\(viewModel.currentStreakDays) Days")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private var monthCompletionMiniCard: some View {
        HStack(spacing: 12) {
            ConicRingProgressView(progress: Double(viewModel.monthCompletionPercent) / 100, label: "\(viewModel.monthCompletionPercent)%")
            VStack(alignment: .leading, spacing: 4) {
                Text("MONTH COMPLETION")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                Text("\(viewModel.monthCompletionPercent)%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private func statTile(title: String, value: String, suffix: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                .tracking(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(DesignTokens.primaryColor)
                Text(suffix)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
            }
            Text(caption)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.primary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private func statLowTile(title: String, value: String, suffix: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                .tracking(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 32, weight: .heavy))
                    .foregroundStyle(Color.primary)
                Text(suffix)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
            }
            Text(caption)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.primary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
    }

    private var aiInsightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                Text("AI INSIGHT")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(DesignTokens.primaryColor)
                    .tracking(1.2)
            }
            ForEach(viewModel.aiInsights, id: \.self) { line in
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DesignTokens.primaryColor)
                        .frame(width: 6)
                        .frame(maxHeight: .infinity)
                    Text(line)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.2, green: 0.22, blue: 0.28))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.primaryColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(DesignTokens.primaryColor.opacity(0.2), lineWidth: 2)
        )
    }

    // MARK: - Monthly (statistics_2)

    private var monthlyContent: some View {
        VStack(spacing: 24) {
            heatmapCard
            patternSummarySection
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Share Report Card")
                        .font(.system(size: 17, weight: .heavy))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignTokens.primaryColor)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: DesignTokens.primaryColor.opacity(0.35), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)
        }
    }

    private var heatmapCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(viewModel.heatmapMonthTitle.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                    .tracking(1)
                Spacer()
                HStack(spacing: 4) {
                    Text("Low")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                    HStack(spacing: 2) {
                        ForEach([0.1, 0.4, 0.7, 1.0], id: \.self) { o in
                            Circle()
                                .fill(DesignTokens.primaryColor.opacity(o))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("High")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                }
            }

            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                        .frame(maxWidth: .infinity)
                }
                ForEach(viewModel.heatmapCells) { cell in
                    if let i = cell.intensity {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DesignTokens.primaryColor.opacity(i))
                            .aspectRatio(1, contentMode: .fit)
                    } else {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(Color(red: 0.88, green: 0.89, blue: 0.91))
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.96, green: 0.97, blue: 0.98)))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            Text("Intensity represents your daily score")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
        .padding(.horizontal, 24)
    }

    private var patternSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PATTERN SUMMARY")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                .tracking(1)
                .padding(.horizontal, 24)
            VStack(spacing: 24) {
                ForEach(viewModel.patternRows) { row in
                    patternRowView(row)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 2))
            .padding(.horizontal, 24)
        }
    }

    private func patternRowView(_ row: PatternSummaryRow) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(row.accent == .green ? Color.green.opacity(0.12) : row.accent == .primary ? DesignTokens.primaryColor.opacity(0.12) : Color(red: 0.95, green: 0.96, blue: 0.97))
                    .frame(width: 40, height: 40)
                Image(systemName: row.symbolName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(row.accent == .green ? Color.green : row.accent == .primary ? DesignTokens.primaryColor : Color(red: 0.45, green: 0.48, blue: 0.52))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.primary)
                Text(row.subtitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Weekly bar chart (custom, matches Figma)

private struct WeeklyBarChartView: View {
    let columns: [WeeklyBarColumn]

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .trailing, spacing: 0) {
                weeklyAxisLabel("100")
                Spacer()
                weeklyAxisLabel("50")
                Spacer()
                weeklyAxisLabel("0")
            }
            .frame(width: 24)
            .padding(.bottom, 24)

            ZStack(alignment: .bottomLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        Divider().background(Color(red: 0.95, green: 0.96, blue: 0.97))
                        Spacer()
                    }
                }
                .padding(.bottom, 24)

                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(columns) { col in
                        VStack(spacing: 0) {
                            if col.isHighlight, let reason = col.reason, let score = col.score {
                                WeeklyTooltipBubble(weekdayIndex: col.id, reason: reason, score: score)
                                    .padding(.bottom, 8)
                            }
                            GeometryReader { geo in
                                let h = max(8, geo.size.height * col.heightFraction)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(DesignTokens.primaryColor)
                                    .opacity(col.isHighlight ? 1 : 0.3)
                                    .frame(height: h)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .stroke(Color.white, lineWidth: col.isHighlight ? 2 : 0)
                                    )
                            }
                            .frame(height: 140)
                            Text(col.weekdayLetter)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(col.isHighlight ? DesignTokens.primaryColor : Color(red: 0.55, green: 0.58, blue: 0.62))
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.leading, 8)
            }
            .overlay(alignment: .bottomLeading) {
                Rectangle()
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.97))
                    .frame(width: 2, height: 140)
                    .offset(x: 0, y: -24)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.97))
                    .frame(height: 2)
                    .offset(y: -24)
            }
        }
        .frame(height: 220)
    }

    private func weeklyAxisLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(Color(red: 0.45, green: 0.51, blue: 0.57))
    }
}

private struct WeeklyTooltipBubble: View {
    let weekdayIndex: Int
    let reason: String
    let score: Int

    private static let weekdayTitles = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\"\(reason)\"")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack {
                Text(Self.weekdayTitles[safe: weekdayIndex] ?? "THURSDAY")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(DesignTokens.primaryColor)
                Spacer()
                Text("\(score)/100")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
            }
            .padding(.top, 4)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(red: 0.95, green: 0.96, blue: 0.97))
                    .frame(height: 1)
                    .offset(y: -4)
            }
        }
        .padding(12)
        .frame(width: 180)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black, lineWidth: 2))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            TrianglePointerDown()
                .fill(Color.black)
                .frame(width: 14, height: 8)
                .offset(y: 6)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct TrianglePointerDown: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Conic ring (streak / completion)

private struct ConicRingProgressView: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.95, green: 0.96, blue: 0.97), lineWidth: 4)
                .frame(width: 36, height: 36)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(DesignTokens.primaryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
            Circle()
                .fill(Color.white)
                .frame(width: 28, height: 28)
            Text(label)
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(Color.primary)
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Share sheet

struct InstagramStoryShareSheet: View {
    @ObservedObject var viewModel: StatsViewModel
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(DesignTokens.primaryColor.opacity(0.2))
                    .frame(width: 48, height: 6)
                    .padding(.vertical, 12)

                Text("SHARE YOUR MONTH")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                    .tracking(2)
                    .padding(.bottom, 8)

                storyPreviewCard
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button(action: {}) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share to Instagram Story")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(DesignTokens.primaryColor)
                        .clipShape(Capsule())
                        .shadow(color: DesignTokens.primaryColor.opacity(0.25), radius: 10, x: 0, y: 4)
                    }
                    Button(action: {}) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.down.circle")
                            Text("Save to Gallery")
                        }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.clear)
                        .overlay(Capsule().stroke(DesignTokens.primaryColor.opacity(0.2), lineWidth: 2))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                Button("Not now", action: onDismiss)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                    .padding(.top, 20)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .background(Color(hex: "F8F5F5"))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.top, 80)
        }
    }

    private var storyPreviewCard: some View {
        VStack(spacing: 16) {
            ScoorLogo(size: 34, variant: .red)
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                Text("MONTHLY REPORT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor.opacity(0.6))
                    .tracking(1.2)
                Text(viewModel.shareMonthLine)
                    .font(.system(size: 36, weight: .heavy))
                    .foregroundStyle(DesignTokens.primaryColor)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(0..<14, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(DesignTokens.primaryColor.opacity([0.8, 0.4, 0.9, 0.2, 0.1, 0.6, 0.7, 0.3, 1, 0.5, 0.9, 0.1, 0.6, 0.4][i]))
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(12)
            .background(DesignTokens.primaryColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Monthly score intensity")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))

            VStack(spacing: 0) {
                shareRow(label: "Average", value: viewModel.shareAveragePts)
                shareTopDayRow(
                    topScore: viewModel.shareTopScore.map { "\($0)" } ?? "—",
                    dateLabel: viewModel.shareTopDateLabel
                )
                shareRow(label: "Streak", value: "\(viewModel.shareStreakDays) Days")
            }

            Text("Generated by Scoor for iOS")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DesignTokens.primaryColor.opacity(0.06), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
    }

    private func shareRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.primary)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignTokens.primaryColor.opacity(0.1)).frame(height: 1)
        }
    }

    private func shareTopDayRow(topScore: String, dateLabel: String) -> some View {
        HStack(alignment: .center) {
            Text("Top Day")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(topScore)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.primary)
                if !dateLabel.isEmpty {
                    Text(dateLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignTokens.primaryColor)
                }
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DesignTokens.primaryColor.opacity(0.1)).frame(height: 1)
        }
    }
}

#Preview("Statistics") {
    let (score, user, _) = PreviewData.makePreviewServices()
    return NavigationStack {
        StatsView(scoreService: score, userService: user)
    }
}
