//
//  SupabaseAuthClient.swift
//  Scoor
//
//  GoTrue (Supabase Auth) REST calls (spec-13 §6, C4/C5).
//
//  This is what turns a sign-in into a *server* user id. The local
//  `AuthenticatedIdentity.stableUserID` (SHA-256 of provider:subject) was only
//  ever a stand-in for one; once a session exists, `auth.users.id` is the single
//  identity every row is keyed by — which is what actually fixes P0-7 rather
//  than papering over it, since the id no longer depends on the device.
//
//  Deliberately separate from SupabaseHTTPClient: that type asks *this* one for
//  tokens, so having it route its own calls through there would be circular.
//

import Foundation

/// A live Supabase session. Tokens are persisted to the Keychain by AuthService;
/// this value type only carries them.
struct SupabaseSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    /// Absolute expiry, derived from `expires_in` at receipt.
    let expiresAt: Date
    let userId: UUID
    let email: String?

    /// Treat a token as expired slightly early so a request doesn't start with a
    /// token that dies mid-flight.
    func isExpired(now: Date = Date(), leeway: TimeInterval = 60) -> Bool {
        now.addingTimeInterval(leeway) >= expiresAt
    }
}

actor SupabaseAuthClient {

    private let config: SupabaseConfig
    private let session: URLSession

    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Email

    /// Create an account. When the project requires email confirmation the
    /// response carries a user but no session — the caller must tell the user to
    /// check their inbox rather than treat it as a completed sign-in.
    func signUp(email: String, password: String) async throws -> SupabaseSession? {
        let body = ["email": email, "password": password]
        let response: TokenResponse = try await post("signup", body: body)
        return response.session
    }

    func signIn(email: String, password: String) async throws -> SupabaseSession {
        let body = ["email": email, "password": password]
        let response: TokenResponse = try await post("token", query: ["grant_type": "password"], body: body)
        guard let session = response.session else { throw APIError.unauthorized }
        return session
    }

    /// Exchange an Apple/Google identity token for a Supabase session.
    ///
    /// Requires the provider to be configured in the Supabase dashboard — the
    /// server verifies the token against the provider's JWKS, which is the
    /// verification the app was previously trusting the client to do (spec-13 §6.1).
    func signInWithIdToken(provider: String, idToken: String, nonce: String? = nil) async throws -> SupabaseSession {
        var body = ["provider": provider, "id_token": idToken]
        if let nonce { body["nonce"] = nonce }
        let response: TokenResponse = try await post("token", query: ["grant_type": "id_token"], body: body)
        guard let session = response.session else { throw APIError.unauthorized }
        return session
    }

    // MARK: - Session lifecycle

    func refresh(refreshToken: String) async throws -> SupabaseSession {
        let body = ["refresh_token": refreshToken]
        let response: TokenResponse = try await post("token", query: ["grant_type": "refresh_token"], body: body)
        guard let session = response.session else { throw APIError.unauthorized }
        return session
    }

    /// Best-effort server-side revocation. A failure here must not block local
    /// sign-out — the user asked to leave, and the token expires on its own.
    func signOut(accessToken: String) async {
        _ = try? await postRaw("logout", body: [String: String](), accessToken: accessToken)
    }

    /// Delete the signed-in user's account (P0-4).
    ///
    /// Routed through an Edge Function because deletion needs the service-role key
    /// — which must never ship in the app — and because Apple requires the
    /// provider token to be revoked server-side, not just locally.
    func deleteAccount(accessToken: String) async throws {
        var request = URLRequest(url: config.functionsURL.appendingPathComponent("account-delete"))
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw Self.error(from: data, status: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // MARK: - Transport

    private func post<T: Decodable>(_ path: String,
                                    query: [String: String] = [:],
                                    body: [String: String]) async throws -> T {
        let data = try await postRaw(path, query: query, body: body)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    @discardableResult
    private func postRaw(_ path: String,
                         query: [String: String] = [:],
                         body: [String: String],
                         accessToken: String? = nil) async throws -> Data {
        guard var components = URLComponents(
            url: config.authURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.decoding("bad auth URL") }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.decoding("bad auth URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding("non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw Self.error(from: data, status: http.statusCode)
        }
        return data
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
                 .internationalRoamingOff, .secureConnectionFailed:
                throw APIError.offline
            default:
                throw APIError.server(status: error.errorCode, message: error.localizedDescription)
            }
        }
    }

    /// Map GoTrue's error payload onto APIError, keeping the codes the sign-up
    /// screen needs to distinguish (wrong password vs. already registered).
    private static func error(from data: Data, status: Int) -> APIError {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = json?["error_code"] as? String
        let message = (json?["msg"] as? String)
            ?? (json?["error_description"] as? String)
            ?? (json?["message"] as? String)

        switch (status, code) {
        case (400, "invalid_credentials"), (400, "invalid_grant"), (401, _):
            return .unauthorized
        case (422, "user_already_exists"), (400, "user_already_exists"):
            return .rejected("이미 가입된 이메일입니다.")
        case (429, _):
            return .rateLimited
        case (400, "email_address_invalid"):
            return .rejected("사용할 수 없는 이메일 주소입니다.")
        case (400, "weak_password"), (422, "weak_password"):
            return .rejected("비밀번호가 너무 약합니다. 6자 이상으로 설정해 주세요.")
        default:
            return .server(status: status, message: message)
        }
    }
}

// MARK: - Wire model

/// GoTrue token/signup response. Signup with email confirmation on returns a user
/// with no tokens, so every token field is optional and `session` is nil there.
private struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let user: User?

    struct User: Decodable {
        let id: UUID
        let email: String?
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    var session: SupabaseSession? {
        guard let accessToken, let refreshToken, let user else { return nil }
        return SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn ?? 3600),
            userId: user.id,
            email: user.email
        )
    }
}
