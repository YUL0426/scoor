//
//  RemoteModerationService.swift
//  Scoor
//
//  Reporting, blocking, and guideline consent (spec-13 §9).
//
//  This ships *with* the first slice that lets users publish anything — App Store
//  Guideline 1.2 requires a UGC app to offer reporting, blocking, and moderation
//  on day one, so World cannot open without it.
//

import Foundation

@MainActor
final class RemoteModerationService {

    /// Matches `reports.target_type`.
    enum ReportTarget: String {
        case post, comment, guestbook, user, topic, worldScore = "world_score"
    }

    /// Matches `reports.reason`. `selfHarm` routes to support resources rather
    /// than punishment — on an emotion-journaling app this is the report we most
    /// need to get right (spec-13 §9).
    enum ReportReason: String, CaseIterable {
        case spam, abuse, selfHarm = "self_harm", other

        var label: String {
            switch self {
            case .spam:     return String(localized: "스팸 또는 광고")
            case .abuse:    return String(localized: "괴롭힘 또는 혐오")
            case .selfHarm: return String(localized: "자해 또는 자살 위험")
            case .other:    return String(localized: "기타")
            }
        }
    }

    private let client: SupabaseHTTPClient
    private let currentUserID: () -> UUID?

    init(client: SupabaseHTTPClient, currentUserID: @escaping () -> UUID?) {
        self.client = client
        self.currentUserID = currentUserID
    }

    // MARK: - Report

    func report(_ target: ReportTarget,
                id: UUID,
                reason: ReportReason,
                detail: String? = nil) async throws {
        guard let reporterId = currentUserID() else { throw APIError.unauthorized }
        let row = ReportRow(
            reporterId: reporterId,
            targetType: target.rawValue,
            targetId: id,
            reason: reason.rawValue,
            detail: detail
        )
        do {
            try await client.send(try .insert("reports", values: [row]))
        } catch APIError.rejected(let message) where message.contains("duplicate key") && message.contains("reports_reporter_id_target_type_target_id_key") {
            // The unique (reporter, target) index means this user already reported
            // this item. That is success from their point of view — the report is
            // filed — so don't show an error for pressing the button twice.
            return
        }
    }

    // MARK: - Block

    /// Block a user. Their content disappears from this user's World, feed, and
    /// guestbook immediately, enforced by RLS rather than client filtering.
    func block(_ userId: UUID) async throws {
        guard let blockerId = currentUserID() else { throw APIError.unauthorized }
        guard blockerId != userId else { throw APIError.rejected(String(localized: "자신을 차단할 수 없습니다.")) }
        try await client.send(
            try .upsert("blocks",
                        values: [BlockRow(blockerId: blockerId, blockedId: userId)],
                        onConflict: "blocker_id,blocked_id")
        )
    }

    func unblock(_ userId: UUID) async throws {
        guard let blockerId = currentUserID() else { throw APIError.unauthorized }
        try await client.send(.delete("blocks", filters: [
            "blocker_id": SupabaseRequest.eq(blockerId.uuidString.lowercased()),
            "blocked_id": SupabaseRequest.eq(userId.uuidString.lowercased())
        ]))
    }

    /// Blocked users, for the Settings management screen (spec-13 C7).
    func blockedUsers() async throws -> [BlockedUser] {
        guard let blockerId = currentUserID() else { return [] }
        return try await client.send(
            .select("blocks",
                    columns: "blocked_id,created_at,profiles!blocks_blocked_id_fkey(username,avatar_emoji)",
                    filters: ["blocker_id": SupabaseRequest.eq(blockerId.uuidString.lowercased())],
                    order: "created_at.desc"),
            as: [BlockedUser].self
        )
    }

}

// MARK: - Wire models

struct ReportRow: Codable {
    let reporterId: UUID
    let targetType: String
    let targetId: UUID
    let reason: String
    let detail: String?

    enum CodingKeys: String, CodingKey {
        case reporterId = "reporter_id"
        case targetType = "target_type"
        case targetId = "target_id"
        case reason, detail
    }
}

struct BlockRow: Codable {
    let blockerId: UUID
    let blockedId: UUID

    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

struct BlockedUser: Codable, Identifiable {
    let blockedId: UUID
    let createdAt: Date
    let profile: Profile?

    var id: UUID { blockedId }
    var username: String { profile?.username ?? String(localized: "알 수 없는 사용자") }

    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
        case createdAt = "created_at"
        case profile = "profiles"
    }

    struct Profile: Codable {
        let username: String
        let avatarEmoji: String?

        enum CodingKeys: String, CodingKey {
            case username
            case avatarEmoji = "avatar_emoji"
        }
    }
}

struct GuidelineRow: Codable {
    let userId: UUID
    let version: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case version
    }
}
