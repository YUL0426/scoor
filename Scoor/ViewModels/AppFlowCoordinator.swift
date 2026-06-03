//
//  AppFlowCoordinator.swift
//  Scoor
//
//  앱 진입 흐름의 단일 상태 머신.
//
//  Splash → Signup(Welcome → Login → Nickname → Complete) →
//  Onboarding Tour → First Scoor (Prompt → Success) → Main.
//
//  - 각 단계는 `Stage` enum 한 케이스.
//  - 마지막 도달 단계를 UserDefaults에 저장해 두므로,
//    앱을 흐름 중간에 종료해도 같은 단계에서 재개된다.
//

import Combine
import Foundation
import SwiftUI

enum AuthProvider: String, Equatable {
    case apple
    case google
    case email

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "Email"
        }
    }
}

@MainActor
final class AppFlowCoordinator: ObservableObject {

    // MARK: - Stage

    enum Stage: String, Equatable {
        case splash
        case signupWelcome
        case signupLogin
        case signupNickname
        case signupComplete
        case tour
        case firstScoor
        case firstScoorSuccess
        case main
    }

    // MARK: - Persistence keys

    private let stageKey    = "scoor.appFlow"
    private let usernameKey = "scoor.chosenUsername"
    private let avatarKey   = "scoor.chosenAvatarEmoji"
    private let authProviderKey = "scoor.authProvider"
    private let authEmailKey = "scoor.authEmail"
    private let legacyKey   = "hasCompletedOnboarding" // 이전 버전 마이그레이션

    // MARK: - Published

    @Published var stage: Stage = .splash
    @Published var chosenUsername: String = ""
    @Published var chosenAvatarEmoji: String? = nil
    @Published var authProvider: AuthProvider? = nil
    @Published var authEmail: String? = nil

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard

        // 이전 빌드에서 onboarding을 완료한 사용자는 메인으로 바로.
        // 다만 새 가입 흐름을 한 번은 보여주는 게 자연스럽다 — 그래도
        // 기존 사용자가 거부감 없게 하려면 main으로 바로 보내는 게 안전하다.
        if defaults.bool(forKey: legacyKey) && defaults.string(forKey: stageKey) == nil {
            defaults.set(Stage.main.rawValue, forKey: stageKey)
        }

        chosenUsername = defaults.string(forKey: usernameKey) ?? ""
        chosenAvatarEmoji = defaults.string(forKey: avatarKey)
        if let rawProvider = defaults.string(forKey: authProviderKey) {
            authProvider = AuthProvider(rawValue: rawProvider)
        }
        authEmail = defaults.string(forKey: authEmailKey)
    }

    // MARK: - Lifecycle

    /// Splash 화면 종료 시 호출. 저장된 단계로 점프 (또는 가입 시작).
    func didFinishSplash() {
        let raw = UserDefaults.standard.string(forKey: stageKey) ?? Stage.signupWelcome.rawValue
        let resume = Stage(rawValue: raw) ?? .signupWelcome
        // splash 자체는 저장하지 않음 — 매번 짧게 보여준다.
        animate { self.stage = (resume == .splash ? .signupWelcome : resume) }
    }

    // MARK: - 단계 진행

    func continueFromWelcome()   { advance(to: .signupLogin) }
    func continueFromLogin()     { completeAuthentication(provider: .apple) }

    func completeAuthentication(provider: AuthProvider, email: String? = nil) {
        authProvider = provider
        authEmail = email
        UserDefaults.standard.set(provider.rawValue, forKey: authProviderKey)
        if let email, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: authEmailKey)
        }
        advance(to: .signupNickname)
    }

    func continueFromNickname(_ name: String, avatar: String?) {
        chosenUsername = name
        chosenAvatarEmoji = avatar
        UserDefaults.standard.set(name, forKey: usernameKey)
        if let avatar { UserDefaults.standard.set(avatar, forKey: avatarKey) }
        advance(to: .signupComplete)
    }

    func continueFromComplete()    { advance(to: .tour) }
    func continueFromTour()        { advance(to: .firstScoor) }
    func skipFirstScoor()          { advance(to: .main) }
    func didSubmitFirstScoor()     { advance(to: .firstScoorSuccess) }
    func continueFromSuccess()     { advance(to: .main) }

    // MARK: - 점프 (개발/QA)

    func resetForDebug() {
        UserDefaults.standard.removeObject(forKey: stageKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: avatarKey)
        UserDefaults.standard.removeObject(forKey: authProviderKey)
        UserDefaults.standard.removeObject(forKey: authEmailKey)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        chosenUsername = ""
        chosenAvatarEmoji = nil
        authProvider = nil
        authEmail = nil
        animate { self.stage = .splash }
    }

    // MARK: - Helpers

    private func advance(to next: Stage) {
        UserDefaults.standard.set(next.rawValue, forKey: stageKey)
        animate { self.stage = next }
    }

    private func animate(_ change: @escaping () -> Void) {
        withAnimation(.easeInOut(duration: 0.45)) { change() }
    }
}
