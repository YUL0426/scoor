//
//  HomeSections.swift
//  Scoor
//
//  Section components for the emotional Home screen:
//   • TodayHeroCard (3 swipeable slides — today / week pulse / flow)
//   • AIInsightSection (1–3 speech-bubble cards)
//   • LiveFeelingTicker (auto-rotating global mood feed)
//   • RecentEmotionList (last 4 entries as mood cards)
//   • StreakLifeFlowStrip (streak / monthly avg / happiest day)
//

import SwiftUI

// MARK: - 1-1. Today's Scoor (Hero)

struct TodayHeroCard: View {
    @ObservedObject var viewModel: HomeViewModel
    var onTapStartRecording: () -> Void

    @State private var slide = 0
    @State private var animateGlow = false

    private var gradientColors: [Color] {
        MoodPalette.gradient(for: viewModel.todayScore).map { Color(hex: $0) }
    }

    private var glyphColor: Color {
        Color(hex: MoodPalette.glyphTint(for: viewModel.todayScore))
    }

    /// 월요일 시작으로 정렬된 현지화 요일 약자(주간 바 차트 헤더).
    static var weekdayLetters: [String] {
        let syms = Calendar.current.veryShortWeekdaySymbols   // [일,월,화,...] 로캘
        let mondayFirst = [1, 2, 3, 4, 5, 6, 0]
        return mondayFirst.map { syms[$0] }
    }

    var body: some View {
        TabView(selection: $slide) {
            slideToday.tag(0)
            slideWeek.tag(1)
            slideFlow.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 360)
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .bottom) { pageDots }
        .shadow(color: gradientColors.last?.opacity(0.22) ?? .clear, radius: 28, x: 0, y: 14)
        .padding(.horizontal, 20)
        .onAppear { animateGlow = true }
    }

    // MARK: Slide 1 — today

    private var slideToday: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.todayDateLine)
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(glyphColor.opacity(0.85))

            Spacer(minLength: 0)

            if let score = viewModel.todayScore {
                // 점수 100은 숫자 대신 Scoor 로고로(브랜드 규칙).
                ScoreValueView(
                    score: score,
                    font: .system(size: 132, weight: .heavy),
                    color: glyphColor,
                    italic: true,
                    logoHeight: 86,
                    logoVariant: .red
                )
                .contentTransition(.numericText())
            } else {
                ScoorLogo(size: 60, variant: .red)
            }

            Text(viewModel.todayMoodPhrase)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(glyphColor)
                .padding(.top, 6)

            Text(viewModel.todaySubMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(glyphColor.opacity(0.78))
                .padding(.top, 2)

            Spacer(minLength: 0)

            if !viewModel.hasTodayEntry {
                Button(action: onTapStartRecording) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Record today")
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.18))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Slide 2 — this week pulse

    private var slideWeek: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS WEEK")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(glyphColor.opacity(0.85))
                Text(viewModel.weekAverage > 0
                     ? String(localized: "Average \(viewModel.weekAverage)")
                     : String(localized: "Still finding your rhythm"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(glyphColor)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(viewModel.weekScores.enumerated()), id: \.offset) { idx, score in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(glyphColor.opacity(0.18))
                                .frame(width: 18, height: 140)
                            if let s = score {
                                Capsule()
                                    .fill(glyphColor.opacity(0.92))
                                    .frame(width: 18, height: max(8, CGFloat(s) * 1.4))
                            }
                        }
                        Text(Self.weekdayLetters[idx])
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(glyphColor.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 170)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Slide 3 — emotional flow

    private var slideFlow: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("EMOTIONAL FLOW")
                .font(.system(size: 11, weight: .bold))
                .tracking(2)
                .foregroundStyle(glyphColor.opacity(0.85))

            Spacer(minLength: 0)

            Image(systemName: flowSymbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(glyphColor.opacity(0.95))
                .padding(.bottom, 14)

            Text(viewModel.emotionalFlow.displayText)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(glyphColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("Based on the last 14 days")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(glyphColor.opacity(0.65))
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var flowSymbol: String {
        switch viewModel.emotionalFlow {
        case .rising: return "arrow.up.right.circle"
        case .steady: return "circle.dotted"
        case .dipping: return "arrow.down.right.circle"
        case .starting: return "sparkles"
        }
    }

    // MARK: Background

    private var heroBackground: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft animated blobs
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: animateGlow ? 80 : 110, y: animateGlow ? -120 : -90)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animateGlow)

            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: animateGlow ? -90 : -120, y: animateGlow ? 110 : 80)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: animateGlow)
        }
        .allowsHitTesting(false)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(glyphColor.opacity(slide == i ? 0.95 : 0.35))
                    .frame(width: slide == i ? 18 : 6, height: 6)
                    .animation(.easeInOut(duration: 0.25), value: slide)
            }
        }
        .padding(.bottom, 18)
    }
}

// MARK: - 1-2. AI Insight bubbles

struct AIInsightSection: View {
    let insights: [HomeInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                Text("AI INSIGHTS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                ForEach(insights) { insight in
                    AIInsightBubble(insight: insight)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct AIInsightBubble: View {
    let insight: HomeInsight

    private var tintColor: Color {
        switch insight.tint {
        case .primary: return DesignTokens.primaryColor
        case .soft: return Color(hex: "F4A742")
        case .neutral: return Color(hex: "6B7280")
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: insight.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tintColor)
            }
            Text(insight.text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - 1-3. Live Feeling ticker

struct LiveFeelingTicker: View {
    let items: [LiveFeedItem]

    @State private var index = 0
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.18))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulse ? 1.0 : 0.7)
                        .opacity(pulse ? 1.0 : 0.5)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                }
                Text("LIVE")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(Color.green.opacity(0.8))
                Spacer()
                Text("Around the world")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, 20)

            ZStack {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    if i == index {
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DesignTokens.primaryColor)
                                .frame(width: 28)
                            Text(item.text)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DesignTokens.textPrimary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .background(ScoorPalette.bgRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(DesignTokens.primaryColor.opacity(0.12), lineWidth: 0.5)
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            pulse = true
            startTicker()
        }
    }

    private func startTicker() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation(.easeInOut(duration: 0.45)) {
                    index = (index + 1) % max(1, items.count)
                }
            }
        }
    }
}

// MARK: - 1-4. Recent Emotion History

struct RecentEmotionList: View {
    let rows: [HomeRecentRow]
    var onTapEntry: (HomeRecentRow) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("YOUR RECENT DAYS")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(DesignTokens.textSecondary)
                Spacer()
                Text("\(rows.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .padding(.horizontal, 20)

            if rows.isEmpty {
                emptyState
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        Button { onTapEntry(row) } label: {
                            RecentRowCard(row: row)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("recent-day-card")
                        .accessibilityLabel("Recent day, score \(row.score)\(row.mood.map { ", mood \($0.label)" } ?? ""). Tap to edit.")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Your previous days will appear here")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.textSecondary)
            Text("Recording every day builds your story")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(DesignTokens.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ScoorPalette.hairline, lineWidth: 0.5))
    }
}

private struct RecentRowCard: View {
    let row: HomeRecentRow

    private var accent: Color {
        let cols = MoodPalette.gradient(for: row.score).map { Color(hex: $0) }
        return cols.last ?? DesignTokens.primaryColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 2) {
                Text("\(row.score)")
                    .font(.system(size: 28, weight: .heavy))
                    .italic()
                    .foregroundStyle(accent)
                Text(row.dayLabel)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            .frame(width: 56)

            Rectangle()
                .fill(accent.opacity(0.18))
                .frame(width: 2)
                .frame(maxHeight: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.reason)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    if let mood = row.mood {
                        Text("\(mood.emoji) \(mood.label)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(mood.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(mood.tint.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    Text(row.relativeLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
    }
}

// MARK: - 1-5. Streak / Life Flow strip

struct StreakLifeFlowStrip: View {
    let streakDays: Int
    let monthlyAverage: Int
    let happiestWeekday: String

    var body: some View {
        HStack(spacing: 10) {
            chip(icon: "flame.fill", value: streakDays > 0 ? "\(streakDays)d" : "—", label: "STREAK")
            chip(icon: "waveform.path.ecg", value: monthlyAverage > 0 ? "\(monthlyAverage)" : "—", label: "MONTH AVG")
            chip(icon: "sparkle", value: happiestWeekday.isEmpty ? "—" : String(happiestWeekday.prefix(3)).uppercased(with: .current), label: "HAPPIEST")
        }
        .padding(.horizontal, 20)
    }

    private func chip(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                Text(value)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            Text(label)
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
    }
}
