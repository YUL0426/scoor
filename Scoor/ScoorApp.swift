//
//  ScoorApp.swift
//  Scoor
//
//  앱 진입점. 단일 코디네이터(AppFlowCoordinator)가 라우팅한다.
//  - Splash → Stories + social sign-in → Main. Optional setup remains in settings.
//  - 코디네이터는 마지막 단계를 UserDefaults에 저장하므로 흐름 중간 종료 후 재개 가능.
//

import SwiftUI
import SwiftData

/// 실행 환경 판별 헬퍼.
enum AppEnvironment {
    /// 유닛 테스트(XCTest) 호스트로 실행 중인지.
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// Clean-slate hooks for end-to-end UI testing. Activated by the `-uitests-reset`
/// launch argument so each test starts from a known, empty state instead of
/// inheriting scores / onboarding progress left behind by previous runs on the
/// same simulator. (Score CRUD genuinely works; the suites were just flaky
/// because day cells routed to "detail" and keypads opened pre-filled once a
/// prior run had populated the calendar.)
enum UITestSupport {

    /// Whether the UI test runner asked for a fresh slate on this launch.
    static var wantsCleanState: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-uitests-reset")
        #else
        false
        #endif
    }

    #if DEBUG
    /// Enables the in-memory private-journal fixture used only by App Store UI screenshot tests.
    /// The entire hook is compiled out of Release builds.
    static var wantsAppStoreScreenshotFixture: Bool {
        ProcessInfo.processInfo.arguments.contains("-appstore-screenshot-fixture")
    }
    #endif

    /// UserDefaults keys holding onboarding progress + the mock user's identity /
    /// profile. Mirrors the keys written by `AppFlowCoordinator` and
    /// `MockUserService`, so a reset truly returns the app to first-install state.
    private static let stateKeys = [
        "scoor.appFlow",
        "scoor.chosenUsername",
        "scoor.chosenAvatarEmoji",
        "scoor.authProvider",
        "scoor.authEmail",
        "scoor.currentUserId",
        "scoor.userBio",
        "scoor.userEmail",
        "scoor.userGender",
        "scoor.authSession",
        "hasCompletedOnboarding"
    ]

    /// Clear persisted onboarding/identity defaults. MUST run before
    /// `AppServices` / the coordinator read them, so the app comes up fresh.
    static func prepareCleanStateIfNeeded() {
        guard wantsCleanState else { return }
        let defaults = UserDefaults.standard
        for key in stateKeys { defaults.removeObject(forKey: key) }
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("scoor.legal.") {
            defaults.removeObject(forKey: key)
        }
    }

    /// Delete every persisted score so the calendar / home start empty.
    @MainActor
    static func wipeScoresIfNeeded(in context: ModelContext) {
        guard wantsCleanState else { return }
        try? context.delete(model: ScoreModel.self)
        // 소셜 영속(좋아요/댓글/월드점수/팔로우)도 초기화해 UI 테스트 격리 유지.
        try? context.delete(model: LikeRecord.self)
        try? context.delete(model: CommentRecord.self)
        try? context.delete(model: WorldScoreRecord.self)
        try? context.delete(model: FollowRecord.self)
        try? context.delete(model: GuestbookRecord.self)
        try? context.save()
    }
}

@main
struct ScoorApp: App {

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var coordinator = AppFlowCoordinator()
    @StateObject private var services: AppServices
    @StateObject private var authService: AuthService
    /// Theme picked in Settings (system/light/dark) — applied app-wide (P0-5).
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.system.rawValue

    /// Single, app-wide SwiftData container. Created once and shared by both the
    /// SwiftUI environment (`.modelContainer`) and `AppServices` (score persistence).
    private let modelContainer: ModelContainer

    init() {
        // UI tests may request a brand-new-install slate. Clear persisted
        // onboarding/identity defaults *before* services/coordinator read them.
        UITestSupport.prepareCleanStateIfNeeded()

        #if DEBUG
        // Screenshot captures skip onboarding and use only an in-memory private fixture.
        // This branch is not present in Release archives.
        if UITestSupport.wantsAppStoreScreenshotFixture {
            UserDefaults.standard.set(AppFlowCoordinator.Stage.main.rawValue, forKey: "scoor.appFlow")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        #endif

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: ScoreModel.self,
                LikeRecord.self,
                CommentRecord.self,
                WorldScoreRecord.self,
                FollowRecord.self,
                GuestbookRecord.self
            )
        } catch {
            fatalError("Failed to create the Scoor ModelContainer: \(error)")
        }
        modelContainer = container
        // For a clean-state UI test launch, also drop any scores left on disk by
        // previous runs so the calendar/home start empty.
        UITestSupport.wipeScoresIfNeeded(in: container.mainContext)
        // Built here (not inline) so AppServices can borrow it as the token source
        // for the backend stack.
        let auth = AuthService()
        _authService = StateObject(wrappedValue: auth)
        // Inject the container's mainContext so saved scores persist to disk.
        #if DEBUG
        if UITestSupport.wantsAppStoreScreenshotFixture {
            _services = StateObject(wrappedValue: AppServices.appStoreScreenshotFixture())
        } else {
            _services = StateObject(wrappedValue: AppServices(
                modelContext: container.mainContext,
                authService: auth
            ))
        }
        #else
        _services = StateObject(wrappedValue: AppServices(
            modelContext: container.mainContext,
            authService: auth
        ))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
                .environmentObject(coordinator)
                .environmentObject(services)
                .environmentObject(authService)
                .task {
                    // 저장된 리마인더 설정에 맞춰 스케줄을 재확인 — 재설치/재시작 후에도 유지.
                    // 유닛 테스트 호스트에서는 UNUserNotificationCenter 접근이 불안정하므로 건너뛴다.
                    guard !AppEnvironment.isRunningUnitTests else { return }
                    await services.notificationService.refreshSchedule()
                    services.syncScores(userId: authService.currentSession?.userID)
                }
                .onChange(of: scenePhase) { _, phase in
                    // 포그라운드 복귀 시 동기화 (spec-13 §5). 실패는 무소음이라
                    // 사용자 플로우를 막지 않는다.
                    guard phase == .active, !AppEnvironment.isRunningUnitTests else { return }
                    services.syncScores(userId: authService.currentSession?.userID)
                }
                .onReceive(services.legalConsent.$readyUserID) { userID in
                    Task { @MainActor in
                        await Task.yield()
                        services.syncScores(userId: userID)
                    }
                }
                .onChange(of: authService.currentSession?.userID) { _, userID in
                    // 로그인 직후: 큐에 쌓인 로컬 기록을 올리고 서버 기록을 내려받는다.
                    services.syncScores(userId: userID)
                }
        }
        .modelContainer(modelContainer)
    }
}

// MARK: - Root flow

struct RootFlowView: View {

    @EnvironmentObject private var coordinator: AppFlowCoordinator
    @EnvironmentObject private var services: AppServices
    @EnvironmentObject private var authService: AuthService

    @State private var lastSubmittedScore: Int = 0
    @State private var authError: String?
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // 각 stage가 자체 배경을 그리므로 베이스만 깔아둔다.
            Color.black.ignoresSafeArea()

            if coordinator.stage == .splash || isAuthenticating {
                // Keep the entry screen mounted while the provider and receipt finish.
                currentStageView.transition(.opacity)
            } else {
                ConsentGate(service: services.legalConsent) {
                    currentStageView.transition(.opacity)
                }
                .transition(.opacity)
            }

            if isAuthenticating {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.3)
            }
        }
        .onReceive(services.legalConsent.$readyUserID) { userID in
            Task { @MainActor in
                await Task.yield()
                guard let userID, !isAuthenticating,
                      services.legalConsent.permits(userID),
                      let session = authService.currentSession, session.userID == userID,
                      let provider = session.providerKind,
                      coordinator.stage == .signupWelcome || coordinator.stage == .signupLogin else { return }
                // Resume a login whose consent RPC previously failed, without asking
                // the user to authenticate a second time or skipping account migration.
                let previousUserID = await services.userService.getCurrentUser()?.id
                await services.userService.applyAuthenticatedIdentity(
                    provider: session.provider, userID: userID,
                    email: session.email, displayName: session.fullName)
                await services.adoptSignedInAccount(previousLocalUserID: previousUserID, accountUserID: userID)
                coordinator.completeAuthentication(provider: provider, email: session.email)
            }
        }
        .installGlobalKeyboardDismiss()
        .animation(.easeInOut(duration: 0.45), value: coordinator.stage)
        .alert("로그인 실패", isPresented: Binding(
            get: { authError != nil },
            set: { if !$0 { authError = nil } }
        )) {
            Button("확인", role: .cancel) { authError = nil }
        } message: {
            Text(authError ?? "")
        }
    }

    /// Run a real provider sign-in, map the identity onto the local profile, then
    /// advance the onboarding flow. Cancellation is silent; other failures surface
    /// an alert. (Under UI tests AuthService returns a deterministic mock identity.)
    private func performSocialSignIn(_ provider: AuthProvider) {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        Task {
            defer { isAuthenticating = false }
            do {
                // Captured before the profile adopts the account id — afterwards
                // there is no way to know which id the local rows belong to.
                let previousUserID = await services.userService.getCurrentUser()?.id
                let identity = try await authService.signIn(with: provider)
                try await services.legalConsent.acceptTerms(
                    action: provider == .apple ? .apple : .google, userID: identity.resolvedUserID)
                await services.userService.applyAuthenticatedIdentity(
                    provider: provider.rawValue,
                    userID: identity.resolvedUserID,
                    email: identity.email,
                    displayName: identity.fullName
                )
                await services.adoptSignedInAccount(
                    previousLocalUserID: previousUserID,
                    accountUserID: identity.resolvedUserID
                )
                coordinator.completeAuthentication(provider: provider, email: identity.email)
            } catch AuthError.cancelled {
                // User dismissed the sheet — stay on the current screen silently.
            } catch {
                authError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var currentStageView: some View {
        if !authService.isSignedIn && coordinator.stage != .splash && coordinator.stage != .signupLogin {
            signupEntry
        } else {
        switch coordinator.stage {
        case .splash:
            SplashView { coordinator.didFinishSplash() }

        case .signupWelcome:
            signupEntry

        case .signupLogin:
            SignupLoginOptionsView { provider, email in
                // Email keeps its dedicated email/password flow (the view already ran
                // AuthService.signInWithEmail); Apple/Google run through the real
                // provider sign-in.
                if provider == .email {
                    Task {
                        isAuthenticating = true
                        defer { isAuthenticating = false }
                        // Adopt the deterministic email identity so records keyed by
                        // userId survive sign-out/sign-in cycles (P0-7).
                        if let session = authService.currentSession, session.providerKind == .email {
                            do { try await services.legalConsent.acceptTerms(action: .email, userID: session.userID) }
                            catch { authError = error.localizedDescription; return }
                            let previousUserID = await services.userService.getCurrentUser()?.id
                            await services.userService.applyAuthenticatedIdentity(
                                provider: session.provider,
                                userID: session.userID,
                                email: session.email,
                                displayName: session.fullName
                            )
                            await services.adoptSignedInAccount(
                                previousLocalUserID: previousUserID,
                                accountUserID: session.userID
                            )
                        }
                        coordinator.completeAuthentication(provider: provider, email: email)
                    }
                } else {
                    performSocialSignIn(provider)
                }
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
    }

    private var signupEntry: some View {
        SignupWelcomeView(
            onApple: { performSocialSignIn(.apple) },
            onGoogle: { performSocialSignIn(.google) },
            onEmail: { coordinator.continueFromWelcome() }
        )
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

private struct AppEntryView: View {
    @EnvironmentObject private var auth: AuthService
    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitests-consent-recovery") { ConsentRecoveryFixture() }
            else { RootFlowView() }
            #else
            RootFlowView()
            #endif
        }
        .alert(LegalPolicy.text("계정이 삭제됐어요", "Account deleted"), isPresented: $auth.deletionNeedsAppleFollowup) {
            Button(LegalPolicy.text("확인", "OK"), role: .cancel) {}
        } message: {
            Text(LegalPolicy.text("Apple 로그인 연결 해제가 아직 완료되지 않았어요. iPhone 설정의 Apple 계정 → Apple로 로그인 → Scoor에서도 연결을 해제할 수 있어요.", "Apple sign-in access has not yet been revoked. You can also remove Scoor in iPhone Settings → Apple Account → Sign in with Apple."))
        }
    }
}
