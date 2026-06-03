//
//  ScoorApp.swift
//  Scoor
//
//  앱 진입점. 단일 코디네이터(AppFlowCoordinator)가 라우팅한다.
//  - Splash → Signup(4단계) → Onboarding Tour → First Scoor → Main
//  - 코디네이터는 마지막 단계를 UserDefaults에 저장하므로 흐름 중간 종료 후 재개 가능.
//

import SwiftUI
import SwiftData

@main
struct ScoorApp: App {

    @StateObject private var coordinator = AppFlowCoordinator()
    @StateObject private var services: AppServices

    /// Single, app-wide SwiftData container. Created once and shared by both the
    /// SwiftUI environment (`.modelContainer`) and `AppServices` (score persistence).
    private let modelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: ScoreModel.self)
        } catch {
            fatalError("Failed to create the Scoor ModelContainer: \(error)")
        }
        modelContainer = container
        // Inject the container's mainContext so saved scores persist to disk.
        _services = StateObject(wrappedValue: AppServices(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootFlowView()
                .environmentObject(coordinator)
                .environmentObject(services)
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Root flow

struct RootFlowView: View {

    @EnvironmentObject private var coordinator: AppFlowCoordinator
    @EnvironmentObject private var services: AppServices

    @State private var lastSubmittedScore: Int = 0

    var body: some View {
        ZStack {
            // 각 stage가 자체 배경을 그리므로 베이스만 깔아둔다.
            Color.black.ignoresSafeArea()

            currentStageView
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.45), value: coordinator.stage)
    }

    @ViewBuilder
    private var currentStageView: some View {
        switch coordinator.stage {
        case .splash:
            SplashView { coordinator.didFinishSplash() }

        case .signupWelcome:
            SignupWelcomeView(
                onApple: { coordinator.completeAuthentication(provider: .apple) },
                onGoogle: { coordinator.completeAuthentication(provider: .google) },
                onEmail: { coordinator.continueFromWelcome() }
            )

        case .signupLogin:
            SignupLoginOptionsView { provider, email in
                coordinator.completeAuthentication(provider: provider, email: email)
            }

        case .signupNickname:
            SignupNicknameView { name, avatar in
                Task {
                    await services.userService.updateUsername(name)
                    await services.userService.updateAvatarEmoji(avatar)
                    await MainActor.run {
                        coordinator.continueFromNickname(name, avatar: avatar)
                    }
                }
            }

        case .signupComplete:
            SignupCompleteView(
                name: coordinator.chosenUsername,
                avatarEmoji: coordinator.chosenAvatarEmoji
            ) { coordinator.continueFromComplete() }

        case .tour:
            OnboardingView { coordinator.continueFromTour() }

        case .firstScoor:
            FirstScoorPromptView(
                onSubmit: { score, note in
                    await persistFirstScoor(score: score, note: note)
                },
                onSkip: { coordinator.skipFirstScoor() }
            )

        case .firstScoorSuccess:
            FirstScoorSuccessView(submittedScore: lastSubmittedScore) {
                coordinator.continueFromSuccess()
            }

        case .main:
            ContentView()
        }
    }

    /// 첫 점수를 mock score service에 기록하고 success로 이동.
    @MainActor
    private func persistFirstScoor(score: Int, note: String?) async {
        if let user = await services.userService.getCurrentUser() {
            let s = Score(userId: user.id, value: score, reason: note, date: Date())
            try? await services.scoreService.saveScore(s)
            NotificationCenter.default.post(name: .scoorScoreStoreDidChange, object: nil)
        }
        lastSubmittedScore = score
        coordinator.didSubmitFirstScoor()
    }
}

#Preview {
    RootFlowView()
        .environmentObject(AppFlowCoordinator())
        .environmentObject(AppServices())
}
