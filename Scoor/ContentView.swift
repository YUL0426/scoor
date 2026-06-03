//
//  ContentView.swift
//  Scoor
//
//  Root view — 4-탭 구조 (Home / Feed / World / My Page) + 중앙 떠 있는 빨간 "+" FAB.
//
//  탭 변경:
//   - Stats 탭은 제거. 통계는 My Page 안에 흡수 (요약 카드 + 상세 통계 진입).
//   - 두 번째 탭은 사람들의 감정 커뮤니티 “Feed”.
//   - 세 번째 탭은 전세계 토픽의 실시간 감정 “World”.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Hashable {
    case home, feed, world, mypage
}

struct ContentView: View {
    @EnvironmentObject private var appServices: AppServices
    @State private var selectedTab: AppTab = .home
    @State private var showScoreSheet = false

    private let tabTransition = Animation.easeInOut(duration: DesignTokens.animationTabTransitionDuration)

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)

            ScoorTabBar(
                selected: $selectedTab,
                onPlusTap: { showScoreSheet = true }
            )
        }
        .animation(tabTransition, value: selectedTab)
        .sheet(isPresented: $showScoreSheet) {
            ScoreHomeView(
                scoreService: appServices.scoreService,
                userService: appServices.userService
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(
                scoreService: appServices.scoreService,
                userService: appServices.userService,
                onRequestScoreSheet: { showScoreSheet = true }
            )
        case .feed:
            FeedView()
        case .world:
            WorldView()
        case .mypage:
            NavigationStack {
                MyPageView(
                    scoreService: appServices.scoreService,
                    userService: appServices.userService,
                    guestbookService: appServices.guestbookService
                )
            }
        }
    }
}

// MARK: - Custom Tab Bar with Center FAB

private struct ScoorTabBar: View {
    @Binding var selected: AppTab
    var onPlusTap: () -> Void

    private let barHeight: CGFloat = 64
    private let fabSize: CGFloat = 56
    private let fabLift: CGFloat = 18

    var body: some View {
        ZStack(alignment: .top) {
            barBackground

            HStack(spacing: 0) {
                tabItem(.home,   icon: "house",            filledIcon: "house.fill",            label: "Home")
                tabItem(.feed,   icon: "square.stack",     filledIcon: "square.stack.fill",     label: "Feed")

                Color.clear.frame(width: fabSize + 24)

                tabItem(.world,  icon: "globe",            filledIcon: "globe.americas.fill",   label: "World")
                tabItem(.mypage, icon: "person.crop.circle", filledIcon: "person.crop.circle.fill", label: "My Page")
            }
            .frame(height: barHeight)
            .padding(.horizontal, 8)

            fabButton
                .offset(y: -fabLift)
        }
        .frame(maxWidth: .infinity)
        .frame(height: barHeight)
    }

    private var barBackground: some View {
        Rectangle()
            .fill(ScoorPalette.bgBase)
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundStyle(ScoorPalette.hairline),
                alignment: .top
            )
            .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func tabItem(_ tab: AppTab, icon: String, filledIcon: String, label: String) -> some View {
        let isSelected = selected == tab
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selected = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? filledIcon : icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DesignTokens.primaryColor : ScoorPalette.inkTertiary)
                    .frame(height: 24)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? DesignTokens.primaryColor : ScoorPalette.inkTertiary)
                    .lineLimit(1)
                    .opacity(isSelected ? 1 : 1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var fabButton: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onPlusTap()
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: fabSize, height: fabSize)
                .background(
                    LinearGradient(
                        colors: [DesignTokens.primaryColor, DesignTokens.primaryColor.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: DesignTokens.primaryColor.opacity(0.4), radius: 14, x: 0, y: 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(FabPressStyle())
        .accessibilityLabel("Add today's score")
    }
}

private struct FabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview("App (default)") {
    ContentView()
        .environmentObject(AppServices())
}

#Preview("App (with preview data)") {
    let (score, user, guestbook) = PreviewData.makePreviewServices()
    return ContentView()
        .environmentObject(AppServices(scoreService: score, userService: user, guestbookService: guestbook))
}
