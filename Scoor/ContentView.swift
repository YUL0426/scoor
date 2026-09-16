//
//  ContentView.swift
//  Scoor
//
//  Home feed, World, inline record action, and personal archive.
//

import SwiftUI

enum AppTab: Int, CaseIterable, Hashable {
    case home, world, activity, mypage
}

struct ContentView: View {
    @EnvironmentObject private var appServices: AppServices
    @State private var selectedTab: AppTab = .home
    @State private var showScoreSheet = false

    private let tabTransition = Animation.easeInOut(duration: DesignTokens.animationTabTransitionDuration)

    var body: some View {
        VStack(spacing: 0) {
            currentTabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScoorTabBar(
                selected: $selectedTab,
                onPlusTap: { showScoreSheet = true }
            )
        }
        .animation(tabTransition, value: selectedTab)
        .sheet(isPresented: $showScoreSheet) {
            ScoreHomeView(
                scoreService: appServices.scoreService,
                userService: appServices.userService,
                moodAnalyzer: appServices.moodAnalyzer,
                notificationService: appServices.notificationService,
                homeFeedPublisher: appServices.feedService
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(onRequestScoreSheet: { showScoreSheet = true }, onOpenProfile: { selectedTab = .mypage })
        case .world:
            WorldView(socialService: appServices.socialService,
                      worldService: appServices.worldService)
        case .activity:
            ActivityView()
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

// MARK: - Custom Tab Bar with Inline Record Action

private struct ScoorTabBar: View {
    @Binding var selected: AppTab
    var onPlusTap: () -> Void

    private let barHeight: CGFloat = 64
    private let fabSize: CGFloat = 36

    var body: some View {
        ZStack(alignment: .top) {
            barBackground

            HStack(spacing: 0) {
                tabItem(.home,   icon: "house",            filledIcon: "house.fill",            label: "Home")
                tabItem(.world, icon: "globe", filledIcon: "globe.americas.fill", label: "World")
                fabButton.frame(maxWidth: .infinity)
                tabItem(.activity, icon: "heart", filledIcon: "heart.fill", label: "알림")
                tabItem(.mypage, icon: "person.crop.circle", filledIcon: "person.crop.circle.fill", label: "My Page")
            }
            .frame(height: barHeight)
            .padding(.horizontal, 8)

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
            VStack(spacing: 2) {
                Image(systemName: isSelected ? filledIcon : icon)
                    .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? DesignTokens.primaryColor : ScoorPalette.inkTertiary)
                    .frame(height: 36)

                Text(LocalizedStringKey(label))
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? DesignTokens.primaryColor : ScoorPalette.inkTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey(label))
        .accessibilityIdentifier("main-tab-\(label)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var fabButton: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onPlusTap()
        }) {
            VStack(spacing: 2) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: fabSize, height: fabSize)
                    .background(
                        LinearGradient(
                            colors: [DesignTokens.primaryColor, DesignTokens.primaryColor.opacity(0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                Text("기록")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(FabPressStyle())
        .accessibilityLabel("Add today's score")
        .accessibilityIdentifier("main-add-score")
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
