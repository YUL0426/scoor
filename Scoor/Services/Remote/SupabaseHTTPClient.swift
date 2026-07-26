//
//  SupabaseHTTPClient.swift
//  Scoor
//
//  Thin PostgREST / GoTrue client. Deliberately not the supabase-swift SDK:
//  the app already hand-rolls PKCE and OAuth for the same reason (spec-13 §2.2 —
//  keep third-party SDKs out of the dependency graph, keep the wire format
//  visible). The surface we need is small: authed JSON requests, upserts, and a
//  single-flight token refresh.
//
//  Every Remote service goes through this type, so cross-cutting rules
//  (auth headers, 401 refresh-and-retry, min-build gate) live here once.
//

import Foundation

/// Supplies the current access token and refreshes it. Implemented by AuthService
/// so this client has no knowledge of how sessions are stored.
protocol SupabaseTokenProviding: AnyObject, Sendable {
    func currentAccessToken() async -> String?
    /// Exchange the refresh token for a new access token. Returns nil when the
    /// session is unrecoverable and the user must sign in again.
    func refreshAccessToken() async -> String?
}

actor SupabaseHTTPClient {

    private let config: SupabaseConfig
    private let session: URLSession
    private weak var tokenProvider: SupabaseTokenProviding?

    /// Coalesces concurrent refreshes. Without this, a burst of 401s (e.g. the
    /// SyncQueue flushing 30 scores after a flight) would each fire their own
    /// refresh and race to overwrite the session's tokens.
    private var refreshTask: Task<String?, Never>?

    init(config: SupabaseConfig,
         tokenProvider: SupabaseTokenProviding?,
         session: URLSession = .shared) {
        self.config = config
        self.tokenProvider = tokenProvider
        self.session = session
    }

    // MARK: - JSON coding

    /// PostgREST speaks ISO-8601 with fractional seconds; `.iso8601` alone drops
    /// them and round-trips lossily, which matters for last-write-wins ordering.
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(isoFormatter.string(from: date))
        }
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            guard let date = isoFormatter.date(from: raw) ?? isoFallbackFormatter.date(from: raw) else {
                throw APIError.decoding("timestamp: \(raw)")
            }
            return date
        }
        return d
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Postgres omits fractional seconds when they are exactly zero.
    private static let isoFallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Requests

    /// Send a request and decode the response body.
    func send<T: Decodable>(_ request: SupabaseRequest, as type: T.Type) async throws -> T {
        let data = try await perform(request)
        guard !data.isEmpty else { throw APIError.decoding("empty body") }
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Send a request, ignoring the response body (writes with Prefer: return=minimal).
    func send(_ request: SupabaseRequest) async throws {
        _ = try await perform(request)
    }

    private func perform(_ request: SupabaseRequest, isRetry: Bool = false) async throws -> Data {
        let token = await tokenProvider?.currentAccessToken()
        let urlRequest = try build(request, token: token)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError {
            // Anything the URL layer classifies as connectivity is `.offline` so
            // local-first callers can swallow it without inspecting URLError codes.
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotFindHost, .cannotConnectToHost, .dataNotAllowed,
                 .internationalRoamingOff, .secureConnectionFailed:
                throw APIError.offline
            default:
                throw APIError.server(status: error.errorCode, message: error.localizedDescription)
            }
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.decoding("non-HTTP response")
        }

        // Version gate before status handling — a build below the floor should be
        // told to update rather than shown whatever error the server returned.
        if let minBuild = http.value(forHTTPHeaderField: "x-scoor-min-build"),
           Self.isBelowMinimumBuild(minBuild) {
            throw APIError.updateRequired
        }

        switch http.statusCode {
        case 200...299:
            return data

        case 401:
            // One refresh attempt, then give up — a second 401 after a fresh token
            // means the session is genuinely dead, not merely stale.
            guard !isRetry, let provider = tokenProvider else { throw APIError.unauthorized }
            guard await refreshToken(using: provider) != nil else { throw APIError.unauthorized }
            return try await perform(request, isRetry: true)

        case 403:
            // RLS denial. Not retryable: the policy will reject it identically next time.
            throw APIError.rejected(Self.message(from: data) ?? "권한이 없습니다.")

        case 409:
            throw APIError.rejected(Self.message(from: data) ?? "이미 존재하는 데이터입니다.")

        case 429:
            throw APIError.rateLimited

        default:
            throw APIError.server(status: http.statusCode, message: Self.message(from: data))
        }
    }

    private func refreshToken(using provider: SupabaseTokenProviding) async -> String? {
        if let existing = refreshTask { return await existing.value }
        let task = Task { await provider.refreshAccessToken() }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func build(_ request: SupabaseRequest, token: String?) throws -> URLRequest {
        guard var components = URLComponents(
            url: request.base.resolve(in: config).appendingPathComponent(request.path),
            resolvingAgainstBaseURL: false
        ) else { throw APIError.decoding("bad URL") }

        if !request.query.isEmpty {
            components.queryItems = request.query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.decoding("bad URL") }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        // Fall back to the anon key so unauthenticated reads (public topics) work
        // before sign-in; RLS decides what that identity may actually see.
        urlRequest.setValue("Bearer \(token ?? config.anonKey)", forHTTPHeaderField: "Authorization")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        return urlRequest
    }

    // MARK: - Helpers

    /// PostgREST errors are `{"message": "...", "hint": ...}`.
    private static func message(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["message"] as? String ?? json["error_description"] as? String
    }

    private static func isBelowMinimumBuild(_ minBuild: String) -> Bool {
        guard let required = Int(minBuild.trimmingCharacters(in: .whitespaces)),
              let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
              let current = Int(raw)
        else { return false }
        return current < required
    }
}

// MARK: - Request value type

/// A single backend call. Kept as data (not a method per endpoint) so the
/// SyncQueue can hold pending requests and replay them later.
struct SupabaseRequest {

    enum Method: String {
        case get = "GET", post = "POST", patch = "PATCH", delete = "DELETE"
    }

    enum Base {
        case rest, auth, functions

        func resolve(in config: SupabaseConfig) -> URL {
            switch self {
            case .rest:      return config.restURL
            case .auth:      return config.authURL
            case .functions: return config.functionsURL
            }
        }
    }

    var base: Base = .rest
    var method: Method = .get
    var path: String
    var query: [String: String] = [:]
    var headers: [String: String] = [:]
    var body: Data?

    // MARK: Builders

    static func select(_ table: String,
                       columns: String = "*",
                       filters: [String: String] = [:],
                       order: String? = nil,
                       limit: Int? = nil) -> SupabaseRequest {
        var query = filters
        query["select"] = columns
        if let order { query["order"] = order }
        if let limit { query["limit"] = String(limit) }
        return SupabaseRequest(method: .get, path: table, query: query)
    }

    /// Insert-or-update keyed by a unique constraint. Every Phase 1 write uses
    /// this so retries are idempotent (spec-13 §4.3) — a replayed sync upsert
    /// converges instead of erroring on the unique index.
    static func upsert<T: Encodable>(_ table: String,
                                     values: T,
                                     onConflict: String,
                                     returning: Bool = false) throws -> SupabaseRequest {
        SupabaseRequest(
            method: .post,
            path: table,
            query: ["on_conflict": onConflict],
            headers: ["Prefer": "resolution=merge-duplicates,return=\(returning ? "representation" : "minimal")"],
            body: try SupabaseHTTPClient.encoder.encode(values)
        )
    }

    static func insert<T: Encodable>(_ table: String,
                                     values: T,
                                     returning: Bool = false) throws -> SupabaseRequest {
        SupabaseRequest(
            method: .post,
            path: table,
            headers: ["Prefer": "return=\(returning ? "representation" : "minimal")"],
            body: try SupabaseHTTPClient.encoder.encode(values)
        )
    }

    static func delete(_ table: String, filters: [String: String]) -> SupabaseRequest {
        SupabaseRequest(method: .delete, path: table, query: filters,
                        headers: ["Prefer": "return=minimal"])
    }

    /// PostgREST filter syntax helper: `eq.<value>`.
    static func eq(_ value: String) -> String { "eq.\(value)" }
}
