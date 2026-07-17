//
//  AuthService.swift
//  Scoor
//
//  App-wide authentication facade. Combines the real Apple + Google providers,
//  persists the session (UserDefaults) and tokens (Keychain), and exposes the
//  current session as observable state.
//
//  UI-TEST BYPASS: when launched with `-uitests-reset`, the social providers
//  return a deterministic mock identity instead of presenting system UI, so the
//  existing onboarding UI tests (which tap "Continue with Apple") stay green and
//  hermetic. Production / manual runs always use the real providers.
//

import Foundation
import Combine

@MainActor
protocol AuthServiceProtocol: AnyObject {
    var currentSession: AuthSession? { get }
    var isSignedIn: Bool { get }
    func signIn(with provider: AuthProvider) async throws -> AuthenticatedIdentity
    func signInWithApple() async throws -> AuthenticatedIdentity
    func signInWithGoogle() async throws -> AuthenticatedIdentity
    func signInWithEmail(email: String, password: String) async throws -> AuthenticatedIdentity
    func restoreSession()
    func signOut()
}

@MainActor
final class AuthService: ObservableObject, AuthServiceProtocol {

    @Published private(set) var currentSession: AuthSession?
    var isSignedIn: Bool { currentSession != nil }

    private let apple = AppleSignInController()
    private let google = GoogleSignInController()

    private let sessionKey = "scoor.authSession"
    private let tokenKeys = (
        identity: "scoor.auth.identityToken",
        access: "scoor.auth.accessToken",
        refresh: "scoor.auth.refreshToken"
    )

    init() { restoreSession() }

    // MARK: - Sign in

    func signIn(with provider: AuthProvider) async throws -> AuthenticatedIdentity {
        switch provider {
        case .apple:  return try await signInWithApple()
        case .google: return try await signInWithGoogle()
        case .email:  throw AuthError.notConfigured("이메일 로그인은 별도 플로우를 사용합니다.")
        }
    }

    func signInWithApple() async throws -> AuthenticatedIdentity {
        let identity = UITestSupport.wantsCleanState
            ? Self.mockIdentity(provider: .apple)
            : try await apple.signIn()
        persist(identity)
        return identity
    }

    func signInWithGoogle() async throws -> AuthenticatedIdentity {
        let identity = UITestSupport.wantsCleanState
            ? Self.mockIdentity(provider: .google)
            : try await google.signIn()
        persist(identity)
        return identity
    }

    /// Email flow: creates the device-local account on first use (salted PBKDF2
    /// hash in the Keychain), verifies the password on subsequent sign-ins, and
    /// derives the user id deterministically from the email — so signing out and
    /// back in restores the same identity and all records keyed by it (P0-7).
    func signInWithEmail(email: String, password: String) async throws -> AuthenticatedIdentity {
        let normalized = EmailCredentialStore.normalize(email)
        // PBKDF2 is deliberately slow — keep it off the main actor.
        _ = try await Task.detached(priority: .userInitiated) {
            try EmailCredentialStore.registerOrVerify(email: normalized, password: password)
        }.value
        let identity = AuthenticatedIdentity(
            provider: .email,
            providerUserID: normalized,
            email: normalized
        )
        persist(identity)
        return identity
    }

    // MARK: - Session lifecycle

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            currentSession = nil
            return
        }
        currentSession = session
    }

    func signOut() {
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        KeychainStore.delete(tokenKeys.identity)
        KeychainStore.delete(tokenKeys.access)
        KeychainStore.delete(tokenKeys.refresh)
    }

    // MARK: - Persistence

    private func persist(_ identity: AuthenticatedIdentity) {
        let session = AuthSession(
            provider: identity.provider.rawValue,
            providerUserID: identity.providerUserID,
            email: identity.email,
            fullName: identity.fullName,
            userID: identity.stableUserID,
            signedInAt: Date()
        )
        currentSession = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
        KeychainStore.set(identity.identityToken, for: tokenKeys.identity)
        KeychainStore.set(identity.accessToken, for: tokenKeys.access)
        KeychainStore.set(identity.refreshToken, for: tokenKeys.refresh)
    }

    // MARK: - UI-test mock

    private static func mockIdentity(provider: AuthProvider) -> AuthenticatedIdentity {
        AuthenticatedIdentity(
            provider: provider,
            providerUserID: "uitest-\(provider.rawValue)",
            email: "scoorqa@scoor.app",
            fullName: "Scoor QA",
            identityToken: "uitest.identity.token"
        )
    }
}
