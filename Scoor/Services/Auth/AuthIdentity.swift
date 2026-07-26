//
//  AuthIdentity.swift
//  Scoor
//
//  Value types for the real account system: the result of a provider sign-in,
//  the persisted session, and auth errors. Token material is kept out of these
//  value types' persistence path (AuthService stores tokens in the Keychain).
//

import Foundation
import CryptoKit

/// Result of a successful provider sign-in. The app-wide local user id is derived
/// deterministically from (provider + providerUserID) so the same account always
/// maps to the same local identity across launches.
struct AuthenticatedIdentity: Equatable {
    let provider: AuthProvider
    /// Apple `user` identifier or Google `sub` claim — stable per account.
    let providerUserID: String
    var email: String?
    var fullName: String?
    /// Raw tokens (persisted to Keychain by AuthService, never to UserDefaults).
    var identityToken: String?
    var accessToken: String?
    var refreshToken: String?
    /// `auth.users.id` once a Supabase session exists. Nil in local-only builds.
    var serverUserID: UUID?

    init(
        provider: AuthProvider,
        providerUserID: String,
        email: String? = nil,
        fullName: String? = nil,
        identityToken: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        serverUserID: UUID? = nil
    ) {
        self.provider = provider
        self.providerUserID = providerUserID
        self.email = email
        self.fullName = fullName
        self.identityToken = identityToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.serverUserID = serverUserID
    }

    /// The id every local record is keyed by.
    ///
    /// Prefers the server id: it is stable across devices, which the derived
    /// `stableUserID` never was — that one only survived sign-out on the *same*
    /// device, which is as far as P0-7 could go without a backend.
    var resolvedUserID: UUID { serverUserID ?? stableUserID }

    /// Deterministic, stable UUID for this account (UUIDv5-style: SHA256 of
    /// "provider:subject", with version/variant bits set).
    var stableUserID: UUID {
        AuthenticatedIdentity.deterministicUUID(from: "\(provider.rawValue):\(providerUserID)")
    }

    static func deterministicUUID(from string: String) -> UUID {
        let digest = SHA256.hash(data: Data(string.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50 // version 5
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // RFC 4122 variant
        let t = (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                 bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15])
        return UUID(uuid: t)
    }
}

/// Persisted authenticated session (no token material — tokens live in Keychain).
struct AuthSession: Codable, Equatable {
    let provider: String
    let providerUserID: String
    var email: String?
    var fullName: String?
    let userID: UUID
    let signedInAt: Date

    var providerKind: AuthProvider? { AuthProvider(rawValue: provider) }
}

/// User-facing auth errors with Korean copy for inline messaging.
enum AuthError: LocalizedError, Equatable {
    case cancelled
    case notConfigured(String)
    case failed(String)
    case invalidResponse
    /// Sign-up succeeded but the project requires a confirmed email before the
    /// account can be used, so there is no session yet.
    case emailConfirmationRequired(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:            return "로그인이 취소되었습니다."
        case .notConfigured(let w): return "설정이 필요합니다: \(w)"
        case .failed(let m):        return "로그인에 실패했습니다: \(m)"
        case .invalidResponse:      return "로그인 응답이 올바르지 않습니다."
        case .emailConfirmationRequired(let email):
            return "\(email)로 확인 메일을 보냈습니다. 메일의 링크를 눌러 가입을 완료해 주세요."
        }
    }
}
