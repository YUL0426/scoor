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
    @State private var showMyScoors = false
    @State private var myScoors: [MyScoorEntry] = []
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
        .task {
            await viewModel.load()
            myScoors = await appServices.socialService.myWorldScores()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoorScoreStoreDidChange)) { _ in
            Task { await viewModel.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoorSocialStoreDidChange)) { _ in
            Task { myScoors = await appServices.socialService.myWorldScores() }
        }
        // Home 우상단 프로필 아이콘 → "My Scoors"(내가 점수 매긴 토픽 이력). My Page와 별개.
        .sheet(isPresented: $showMyScoors) {
            NavigationStack {
                MyScoorsView(entries: myScoors)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showMyScoors = false } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .accessibilityLabel("닫기")
                        }
                    }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editTarget) { target in
            ScoreHomeView(
                scoreService: appServices.scoreService,
                userService: appServices.userService,
                moodAnalyzer: appServices.moodAnalyzer,
                notificationService: appServices.notificationService,
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

            Button {
                showMyScoors = true
                Task { myScoors = await appServices.socialService.myWorldScores() }
            } label: {
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
            .accessibilityLabel("My Scoors")
            .accessibilityIdentifier("home-profile-button")
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
