//
//  AuthService.swift
//  Scoor
//
//  App-wide authentication facade. Combines the real Apple + Google providers,
//  persists the session (UserDefaults) and tokens (Keychain), and exposes the
//  current session as observable state.
//
//  BACKEND (spec-13 §6, C4): when `SupabaseConfig` is provisioned every sign-in
//  is exchanged for a real Supabase session and the account id becomes
//  `auth.users.id` — server-issued, so records follow the account across devices.
//  With no backend configured the service keeps its previous device-local
//  behavior unchanged, which is what lets previews, unit tests, and
//  un-provisioned checkouts keep working.
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
    func deleteAccount() async throws
}

@MainActor
final class AuthService: ObservableObject, AuthServiceProtocol {

    @Published var deletionNeedsAppleFollowup = false
    @Published private(set) var currentSession: AuthSession?
    var isSignedIn: Bool { currentSession != nil }

    private let apple = AppleSignInController()
    private let google = GoogleSignInController()

    /// Nil when the backend is not provisioned — the signal that every path
    /// below uses to decide between server and device-local behavior.
    private let supabase: SupabaseAuthClient?
    /// Live tokens. Mirrored to the Keychain so they survive relaunch.
    private var supabaseSession: SupabaseSession?

    private let sessionKey = "scoor.authSession"
    private let supabaseSessionKey = "scoor.auth.supabaseSession"
    private let tokenKeys = (
        identity: "scoor.auth.identityToken",
        access: "scoor.auth.accessToken",
        refresh: "scoor.auth.refreshToken"
    )

    init(config: SupabaseConfig? = SupabaseConfig.current, session: URLSession = .shared) {
        self.supabase = config.map { SupabaseAuthClient(config: $0, session: session) }
        restoreSession()
    }

    /// Whether this build authenticates against the backend.
    var isBackendBacked: Bool { supabase != nil }

    // MARK: - Sign in

    func signIn(with provider: AuthProvider) async throws -> AuthenticatedIdentity {
        switch provider {
        case .apple:  return try await signInWithApple()
        case .google: return try await signInWithGoogle()
        case .email:  throw AuthError.notConfigured(String(localized: "이메일 로그인은 별도 플로우를 사용합니다."))
        }
    }

    func signInWithApple() async throws -> AuthenticatedIdentity {
        if UITestSupport.wantsCleanState {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-uitests-auth-cancel") { throw AuthError.cancelled }
            #endif
            let identity = Self.mockIdentity(provider: .apple)
            persist(identity)
            return identity
        }
        let identity = try await apple.signIn()
        return try await finish(identity, providerName: "apple")
    }

    func signInWithGoogle() async throws -> AuthenticatedIdentity {
        if UITestSupport.wantsCleanState {
            let identity = Self.mockIdentity(provider: .google)
            persist(identity)
            return identity
        }
        let identity = try await google.signIn()
        return try await finish(identity, providerName: "google")
    }

    /// Email flow.
    ///
    /// Backend: signs in, falling back to sign-up on the first attempt for an
    /// unknown address — this preserves the one-step UX the screen already has,
    /// where the same button both registers and logs in.
    ///
    /// No backend: creates the device-local account (salted PBKDF2 hash in the
    /// Keychain) and derives the id from the email, as before.
    func signInWithEmail(email: String, password: String) async throws -> AuthenticatedIdentity {
        let normalized = EmailCredentialStore.normalize(email)

        guard let supabase else {
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

        let session: SupabaseSession
        do {
            session = try await supabase.signIn(email: normalized, password: password)
        } catch APIError.unauthorized {
            // Either a new address or a wrong password; sign-up tells us which.
            do {
                guard let created = try await supabase.signUp(email: normalized, password: password) else {
                    // Confirmation required: the account exists but cannot be used yet.
                    throw AuthError.emailConfirmationRequired(normalized)
                }
                session = created
            } catch APIError.rejected(let message) where message == String(localized: "이미 가입된 이메일입니다.") {
                // The address is taken, so the password was simply wrong.
                throw AuthError.failed(String(localized: "비밀번호가 올바르지 않습니다."))
            }
        }

        adopt(session)
        let identity = AuthenticatedIdentity(
            provider: .email,
            providerUserID: normalized,
            email: session.email ?? normalized,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            serverUserID: session.userId
        )
        persist(identity)
        return identity
    }

    /// A configured backend must verify the identity before sign-in succeeds.
    func finish(_ identity: AuthenticatedIdentity,
                providerName: String) async throws -> AuthenticatedIdentity {
        guard let supabase else {
            persist(identity)
            return identity
        }
        guard let idToken = identity.identityToken else { throw AuthError.invalidResponse }
        let session = try await supabase.signInWithIdToken(provider: providerName, idToken: idToken)
        adopt(session)
        var resolved = identity
        resolved.serverUserID = session.userId
        resolved.accessToken = session.accessToken
        resolved.refreshToken = session.refreshToken
        persist(resolved)
        return resolved
    }

    // MARK: - Session lifecycle

    func restoreSession() {
        if let data = KeychainStore.get(supabaseSessionKey)?.data(using: .utf8),
           let stored = try? JSONDecoder().decode(SupabaseSession.self, from: data) {
            supabaseSession = stored
        }

        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            currentSession = nil
            return
        }
        currentSession = session
    }

    func signOut() {
        if let token = supabaseSession?.accessToken, let supabase {
            Task { await supabase.signOut(accessToken: token) }
        }
        supabaseSession = nil
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        KeychainStore.delete(supabaseSessionKey)
        KeychainStore.delete(tokenKeys.identity)
        KeychainStore.delete(tokenKeys.access)
        KeychainStore.delete(tokenKeys.refresh)
    }

    /// Delete the account (App Store 5.1.1(v), P0-4).
    ///
    /// With a backend this calls the `account-delete` Edge Function, which holds
    /// the service-role key and revokes the Apple token — neither of which can
    /// happen in the client.
    ///
    /// **The server call is awaited and its failure is rethrown.** It used to be
    /// fired into a detached `Task` whose error was swallowed, so a request that
    /// never landed still cleared the device and looked like success: the account
    /// survived on the server while the user was told it was gone. 5.1.1(v) asks
    /// for deletion, not for a sign-out that resembles one.
    func deleteAccount() async throws {
        let wasApple = currentSession?.providerKind == .apple
        var appleRevoked = !wasApple
        if let supabase {
            let code = await freshAppleAuthorizationCode()
            guard let token = await currentAccessToken() else { throw APIError.unauthorized }
            appleRevoked = try await supabase.deleteAccount(accessToken: token, appleAuthorizationCode: code)
        }
        if let session = currentSession, session.providerKind == .email {
            EmailCredentialStore.removeAccount(email: session.providerUserID)
        }
        signOut()
        deletionNeedsAppleFollowup = wasApple && !appleRevoked
    }

    /// A *newly issued* Apple authorization code, for server-side token revocation.
    ///
    /// Re-authorizing looks redundant — we already had a code at sign-in — but
    /// Apple's codes are single-use and expire in five minutes, so a stored one is
    /// worthless by the time anyone deletes their account. Apple's own guidance is
    /// to request a fresh code at deletion time.
    ///
    /// Returns nil for non-Apple accounts and when the user dismisses the prompt.
    /// A missing code must not block deletion: the user asked to leave, and
    /// refusing to delete because a token could not be revoked would trade one
    /// 5.1.1(v) violation for another.
    private func freshAppleAuthorizationCode() async -> String? {
        guard currentSession?.providerKind == .apple else { return nil }
        // UI 테스트는 시스템 Apple 시트를 띄울 수 없다 — 로그인 경로와 같은 바이패스.
        guard !UITestSupport.wantsCleanState else { return nil }
        return try? await apple.signIn().accessToken
    }

    // MARK: - Persistence

    private func adopt(_ session: SupabaseSession) {
        supabaseSession = session
        if let data = try? JSONEncoder().encode(session),
           let json = String(data: data, encoding: .utf8) {
            KeychainStore.set(json, for: supabaseSessionKey)
        }
    }

    private func persist(_ identity: AuthenticatedIdentity) {
        let session = AuthSession(
            provider: identity.provider.rawValue,
            providerUserID: identity.providerUserID,
            email: identity.email,
            fullName: identity.fullName,
            userID: identity.resolvedUserID,
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

// MARK: - Token supply for the data layer

extension AuthService: SupabaseTokenProviding {

    /// Current access token, refreshed first when it is at or near expiry so the
    /// data layer rarely has to handle a 401 at all.
    func currentAccessToken() async -> String? {
        guard let session = supabaseSession, session.userId == currentSession?.userID else { return nil }
        guard session.isExpired() else { return session.accessToken }
        return await refreshAccessToken()
    }

    func refreshAccessToken() async -> String? {
        guard let supabase, let session = supabaseSession else { return nil }
        do {
            let refreshed = try await supabase.refresh(refreshToken: session.refreshToken)
            // A sign-out/account switch may have happened while the request ran.
            guard supabaseSession?.refreshToken == session.refreshToken else { return nil }
            adopt(refreshed)
            return refreshed.accessToken
        } catch APIError.offline {
            // Keep the session: the token may still be good once we reconnect,
            // and dropping it here would sign the user out for a subway ride.
            return nil
        } catch APIError.unauthorized {
            guard supabaseSession?.refreshToken == session.refreshToken else { return nil }
            supabaseSession = nil
            KeychainStore.delete(supabaseSessionKey)
            return nil
        } catch {
            // Rate limits and server outages must not erase a restorable session.
            return nil
        }
    }
}
