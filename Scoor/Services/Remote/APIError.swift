//
//  APIError.swift
//  Scoor
//
//  Backend errors, shaped like AuthError so both auth and data failures present
//  the same way in the UI (spec-13 §4.3).
//
//  The distinction that matters to callers is `offline` vs everything else:
//  personal journaling must never surface a network failure (spec-13 §5), so the
//  sync layer swallows `.offline` silently, while explicitly online actions
//  (World score submission) show it and offer a retry.
//

import Foundation

enum APIError: LocalizedError, Equatable {
    /// No usable connection. Not a user-facing failure on local-first paths.
    case offline
    /// Backend not provisioned in this build (SupabaseConfig.current == nil).
    case notConfigured
    /// No valid session — the caller should prompt sign-in.
    case unauthorized
    /// Server rejected the write (RLS denial, constraint violation).
    case rejected(String)
    /// Rate limit (spec-13 §11).
    case rateLimited
    /// This build is below `x-scoor-min-build` and must update (spec-13 §4.3).
    case updateRequired
    case server(status: Int, message: String?)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return String(localized: "네트워크에 연결되어 있지 않습니다.")
        case .notConfigured:
            return String(localized: "서버가 설정되지 않았습니다.")
        case .unauthorized:
            return String(localized: "로그인이 필요합니다.")
        case .rejected(let m):
            return String(localized: "요청이 거부되었습니다: \(m)")
        case .rateLimited:
            return String(localized: "너무 자주 시도했습니다. 잠시 후 다시 시도해 주세요.")
        case .updateRequired:
            return String(localized: "앱을 최신 버전으로 업데이트해 주세요.")
        case .server(let status, _):
            return String(localized: "서버 오류(\(status))가 발생했습니다.")
        case .decoding:
            return String(localized: "서버 응답을 처리하지 못했습니다.")
        }
    }

    /// A later explicit agreement can make this write valid. Never discard the
    /// local outbox merely because another device withdrew account consent.
    var isConsentRejection: Bool {
        guard case .rejected(let message) = self else { return false }
        return message.contains("Required agreements must be accepted") ||
               message.contains("Publication agreement must be accepted")
    }

    /// Whether retrying later could plausibly succeed. The SyncQueue keeps work
    /// queued for these and drops it for the rest — a `.rejected` write is
    /// malformed or forbidden and will fail identically forever.
    var isRetryable: Bool {
        switch self {
        case .offline, .rateLimited:
            return true
        case .server(let status, _):
            return status >= 500
        case .notConfigured, .unauthorized, .rejected, .updateRequired, .decoding:
            return false
        }
    }
}
