//
//  GoogleSignInController.swift
//  Scoor
//
//  Real Google Sign-In via the OAuth 2.0 Authorization Code + PKCE flow, using
//  ASWebAuthenticationSession (no third-party SDK). Requires a Google OAuth
//  client id surfaced as `GIDClientID` in Info.plist. ASWebAuthenticationSession
//  consumes the redirect internally via `callbackURLScheme`, so no separate
//  CFBundleURLTypes registration is needed. Without a client id, `signIn()` throws
//  `.notConfigured` and never starts.
//
//  Provisioning (BUG-002, resolved): `GIDClientID` is supplied by Config/Info.plist
//  (INFOPLIST_FILE, merged on top of the generated Info.plist) and expands
//  $(GID_CLIENT_ID) from Config/Secrets.xcconfig — see Config/Secrets.xcconfig.example
//  for setup. When no client id is provisioned, `isConfigured` is false, the UI
//  hides the Google option, and `signIn()` throws `.notConfigured`.
//

import Foundation
import AuthenticationServices

@MainActor
final class GoogleSignInController: NSObject, ASWebAuthenticationPresentationContextProviding {

    struct Config {
        let clientID: String
        /// Reversed client id, used as the custom URL scheme (Google convention).
        let redirectScheme: String
        var redirectURI: String { "\(redirectScheme):/oauth2redirect/google" }

        /// Reads `GIDClientID` from Info.plist; nil when not provisioned for prod.
        static func fromBundle(_ bundle: Bundle = .main) -> Config? {
            guard let clientID = bundle.object(forInfoDictionaryKey: "GIDClientID") as? String,
                  !clientID.isEmpty else { return nil }
            let reversed = clientID.split(separator: ".").reversed().joined(separator: ".")
            return Config(clientID: clientID, redirectScheme: reversed)
        }
    }

    /// Whether Google Sign-In is provisioned in this build (GIDClientID present).
    /// UI uses this to hide the Google option instead of surfacing a dead button.
    static var isConfigured: Bool { Config.fromBundle() != nil }

    private let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    private var session: ASWebAuthenticationSession?

    func signIn() async throws -> AuthenticatedIdentity {
        guard let config = Config.fromBundle() else {
            throw AuthError.notConfigured("Google OAuth 클라이언트 ID(Info.plist의 GIDClientID)")
        }

        let verifier = PKCE.makeCodeVerifier()
        let challenge = PKCE.codeChallengeS256(for: verifier)
        let state = PKCE.makeState()

        guard var comps = URLComponents(string: authEndpoint) else { throw AuthError.invalidResponse }
        comps.queryItems = [
            .init(name: "client_id", value: config.clientID),
            .init(name: "redirect_uri", value: config.redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid email profile"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "state", value: state),
            .init(name: "prompt", value: "select_account")
        ]
        guard let authURL = comps.url else { throw AuthError.invalidResponse }

        let callback = try await presentWebAuth(url: authURL, scheme: config.redirectScheme)
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []

        if let err = items.first(where: { $0.name == "error" })?.value {
            throw err == "access_denied" ? AuthError.cancelled : AuthError.failed(err)
        }
        guard items.first(where: { $0.name == "state" })?.value == state else {
            throw AuthError.failed("state 불일치(보안 검증 실패)")
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw AuthError.cancelled
        }
        return try await exchangeCode(code, verifier: verifier, config: config)
    }

    // MARK: - Web auth presentation

    private func presentWebAuth(url: URL, scheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let error {
                    let ns = error as NSError
                    if ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        cont.resume(throwing: AuthError.cancelled)
                    } else {
                        cont.resume(throwing: AuthError.failed(error.localizedDescription))
                    }
                    return
                }
                guard let callback else { cont.resume(throwing: AuthError.invalidResponse); return }
                cont.resume(returning: callback)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            if !session.start() {
                cont.resume(throwing: AuthError.failed("브라우저 세션을 시작할 수 없습니다."))
            }
        }
    }

    // MARK: - Token exchange

    private func exchangeCode(_ code: String, verifier: String, config: Config) async throws -> AuthenticatedIdentity {
        guard let url = URL(string: tokenEndpoint) else { throw AuthError.invalidResponse }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formEncoded([
            "client_id": config.clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": config.redirectURI
        ])

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.failed("토큰 교환 실패")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidResponse
        }

        let idToken = json["id_token"] as? String
        let accessToken = json["access_token"] as? String
        let refreshToken = json["refresh_token"] as? String
        let claims = idToken.flatMap { JWT.decodePayload($0) } ?? [:]
        let sub = (claims["sub"] as? String) ?? UUID().uuidString
        let email = claims["email"] as? String
        let name = claims["name"] as? String

        return AuthenticatedIdentity(
            provider: .google,
            providerUserID: sub,
            email: email,
            fullName: name,
            identityToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    private func formEncoded(_ params: [String: String]) -> Data? {
        params.map { key, value in
            let v = value.addingPercentEncoding(withAllowedCharacters: .urlFormValueAllowed) ?? value
            return "\(key)=\(v)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }

    // MARK: - Presentation anchor

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        AuthPresentation.keyWindow()
    }
}
