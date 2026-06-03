//
//  HomeView.swift
//  Scoor
//
//  Emotional Home — dark canvas, mood-first, immersive.
//

import SwiftUI

/// Identifiable wrapper so a tapped recent day can drive the edit sheet via `.sheet(item:)`.
struct HomeEditTarget: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}

struct HomeView: View {
    @EnvironmentObject private var appServices: AppServices
    @StateObject private var viewModel: HomeViewModel
    @State private var showProfilePanel = false
    @State private var editTarget: HomeEditTarget?

    var onRequestScoreSheet: () -> Void

    init(
        scoreService: ScoreServiceProtocol,
        userService: UserServiceProtocol,
        onRequestScoreSheet: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(
            scoreService: scoreService,
            userService: userService
        ))
        self.onRequestScoreSheet = onRequestScoreSheet
    }

    var body: some View {
        ZStack(alignment: .top) {
            backgroundCanvas
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    minimalHeader
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    TodayHeroCard(
                        viewModel: viewModel,
                        onTapStartRecording: onRequestScoreSheet
                    )

                    AIInsightSection(insights: viewModel.insights)

                    LiveFeelingTicker(items: viewModel.liveFeed)

                    RecentEmotionList(
                        rows: viewModel.recent,
                        onTapEntry: { row in editTarget = HomeEditTarget(date: row.date) }
                    )

                    StreakLifeFlowStrip(
                        streakDays: viewModel.streakDays,
                        monthlyAverage: viewModel.monthlyAverage,
                        happiestWeekday: viewModel.happiestWeekday
                    )

                    Color.clear.frame(height: 120)
                }
                .padding(.top, 4)
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .scoorScoreStoreDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .sheet(isPresented: $showProfilePanel) {
            HomeProfilePanel(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editTarget) { target in
            ScoreHomeView(
                scoreService: appServices.scoreService,
                userService: appServices.userService,
                targetDate: target.date
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var minimalHeader: some View {
        HStack(alignment: .center) {
            ScoorLogo(size: 24, variant: .white)

            Spacer()

            Button { showProfilePanel = true } label: {
                ZStack {
                    Circle()
                        .fill(DesignTokens.primaryColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DesignTokens.primaryColor)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Background

    private var backgroundCanvas: some View {
        ZStack {
            Color(hex: "0A0A0B")

            Circle()
                .fill(DesignTokens.primaryColor.opacity(0.07))
                .frame(width: 420, height: 420)
                .blur(radius: 90)
                .offset(x: 160, y: -240)
                .allowsHitTesting(false)

            Circle()
                .fill(Color(hex: "8FA9D9").opacity(0.05))
                .frame(width: 380, height: 380)
                .blur(radius: 80)
                .offset(x: -160, y: 280)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Profile Quick Panel

private struct HomeProfilePanel: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(ScoorPalette.hairline)
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            VStack(spacing: 20) {
                // Avatar + name row
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(DesignTokens.primaryColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryColor)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("나의 감정 기록")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ScoorPalette.inkPrimary)
                        Text("Scoor 감정 트래커")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ScoorPalette.inkSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    panelStat(
                        label: "오늘",
                        value: viewModel.todayScore.map { "\($0)" } ?? "—",
                        icon: "sun.max.fill"
                    )
                    panelStat(
                        label: "이번 달 평균",
                        value: viewModel.monthlyAverage > 0 ? "\(viewModel.monthlyAverage)" : "—",
                        icon: "calendar"
                    )
                    panelStat(
                        label: "연속",
                        value: viewModel.streakDays > 0 ? "\(viewModel.streakDays)일" : "—",
                        icon: "flame.fill"
                    )
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .background(ScoorPalette.bgBase)
        .environment(\.colorScheme, .dark)
    }

    private func panelStat(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryColor)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .italic()
                .foregroundStyle(ScoorPalette.inkPrimary)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(ScoorPalette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("Home (with data)") {
    let (score, user, guestbook) = PreviewData.makePreviewServices()
    return HomeView(
        scoreService: score,
        userService: user,
        onRequestScoreSheet: {}
    )
    .environmentObject(AppServices(scoreService: score, userService: user, guestbookService: guestbook))
}

#Preview("Home (empty)") {
    HomeView(
        scoreService: MockScoreService(),
        userService: MockUserService(),
        onRequestScoreSheet: {}
    )
    .environmentObject(AppServices())
}
