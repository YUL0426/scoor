//
//  RemoteWorldService.swift
//  Scoor
//
//  World topics + topic scoring against the backend (spec-13 §3.4, Phase 1).
//
//  Why this is a separate service rather than a `SocialServiceProtocol` conformance:
//  that protocol keys World by `topicTitle` and comments by `authorSeed`, both of
//  which are seed-data artifacts that cannot exist server-side (titles aren't
//  unique and authors are real accounts). spec-13 C2 calls for a v2 protocol that
//  swaps those for `topicId`/`userId`. This type is that v2 surface for the World
//  slice; the feed half of the protocol stays on the local implementation until
//  Phase 2 opens it, so nothing regresses in the meantime.
//

import Foundation

@MainActor
final class RemoteWorldService {

    private let client: SupabaseHTTPClient
    private let currentUserID: () -> UUID?

    init(client: SupabaseHTTPClient, currentUserID: @escaping () -> UUID?) {
        self.client = client
        self.currentUserID = currentUserID
    }

    // MARK: - Topics

    /// Live + closed topics with their aggregate stats, newest first.
    func loadTopics(limit: Int = 50) async throws -> [WorldTopic] {
        // One embedded read instead of N+1: PostgREST joins topic_stats through
        // the FK relationship in a single request.
        let rows: [TopicRow] = try await client.send(
            .select(
                "topics",
                columns: "id,category,title,cover_emoji,status,created_at,topic_stats(*)",
                filters: ["status": "in.(live,closed)"],
                order: "created_at.desc",
                limit: limit
            ),
            as: [TopicRow].self
        )
        return rows.compactMap { $0.toDomain() }
    }

    // MARK: - Scoring

    /// Submit or revise my score for a topic target. Re-submitting is an edit —
    /// the server's `unique (user_id, topic_id, target_id)` makes this idempotent,
    /// so a retry after a flaky response cannot double-count a vote.
    func submitWorldScore(topicId: UUID,
                          targetId: String,
                          score: Int,
                          comment: String?,
                          isAnonymous: Bool,
                          countryCode: String?) async throws {
        guard let userId = currentUserID() else { throw APIError.unauthorized }
        let row = WorldScoreRow(
            userId: userId,
            topicId: topicId,
            targetId: targetId,
            value: max(0, min(100, score)),
            comment: comment,
            isAnonymous: isAnonymous,
            countryCode: countryCode
        )
        try await client.send(
            try .upsert("world_scores", values: [row], onConflict: "user_id,topic_id,target_id")
        )
    }

    /// My scores across all topics — backs the "My Scoors" screen.
    func myWorldScores() async throws -> [WorldScoreRow] {
        guard let userId = currentUserID() else { return [] }
        return try await client.send(
            .select(
                "world_scores",
                filters: ["user_id": SupabaseRequest.eq(userId.uuidString.lowercased())],
                order: "updated_at.desc"
            ),
            as: [WorldScoreRow].self
        )
    }

    /// Recent public reactions to a topic. Blocked users and hidden rows are
    /// filtered by RLS, not here — a client-side filter would still ship the
    /// content to the device.
    func reactions(topicId: UUID, limit: Int = 20) async throws -> [TopicReactionRow] {
        try await client.send(
            .select(
                "world_scores",
                columns: "id,value,comment,is_anonymous,country_code,created_at,profiles(username,avatar_emoji)",
                filters: ["topic_id": SupabaseRequest.eq(topicId.uuidString.lowercased())],
                order: "created_at.desc",
                limit: limit
            ),
            as: [TopicReactionRow].self
        )
    }
}

// MARK: - Wire models

struct TopicRow: Codable {
    let id: UUID
    let category: String
    let title: String
    let coverEmoji: String?
    let createdAt: Date
    let stats: [TopicStatsRow]

    enum CodingKeys: String, CodingKey {
        case id, category, title, createdAt = "created_at"
        case coverEmoji = "cover_emoji"
        case stats = "topic_stats"
    }

    func toDomain() -> WorldTopic? {
        // An unknown category means the server has a topic type this build cannot
        // render. Dropping it beats showing a broken cell.
        guard let category = WorldCategory(rawValue: category) else { return nil }
        let stat = stats.first
        let postsCount = stat?.postsCount ?? 0
        let delta = stat?.scoreDelta ?? 0
        return WorldTopic(
            id: id,
            category: category,
            title: title,
            emoji: coverEmoji ?? category.emoji,
            globalScore: stat?.globalScore ?? 0,
            scoreDelta: delta,
            postsCount: postsCount,
            lastActivityAt: stat?.lastActivityAt ?? createdAt,
            heat: Self.heat(postsCount: postsCount, delta: delta, createdAt: createdAt)
        )
    }

    /// Heat is presentation, derived here rather than stored: the thresholds are a
    /// product decision we expect to tune, and doing it client-side avoids a
    /// migration every time we do.
    private static func heat(postsCount: Int, delta: Int, createdAt: Date) -> TopicHeat {
        if createdAt > Date().addingTimeInterval(-6 * 3600), postsCount < 50 { return .fresh }
        if delta >= 8 { return .rising }
        if delta <= -8 { return .falling }
        if postsCount >= 500 { return .hot }
        return .calm
    }
}

struct TopicStatsRow: Codable {
    let postsCount: Int
    let globalScore: Int?
    let scoreDelta: Int?
    let lastActivityAt: Date?

    enum CodingKeys: String, CodingKey {
        case postsCount = "posts_count"
        case globalScore = "global_score"
        case scoreDelta = "score_delta"
        case lastActivityAt = "last_activity_at"
    }
}

struct WorldScoreRow: Codable, Equatable {
    let userId: UUID
    let topicId: UUID
    let targetId: String
    let value: Int
    let comment: String?
    let isAnonymous: Bool
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case topicId = "topic_id"
        case targetId = "target_id"
        case value, comment
        case isAnonymous = "is_anonymous"
        case countryCode = "country_code"
    }
}

struct TopicReactionRow: Codable {
    let id: UUID
    let value: Int
    let comment: String?
    let isAnonymous: Bool
    let countryCode: String?
    let createdAt: Date
    let profile: ProfileStub?

    enum CodingKeys: String, CodingKey {
        case id, value, comment, createdAt = "created_at"
        case isAnonymous = "is_anonymous"
        case countryCode = "country_code"
        case profile = "profiles"
    }

    struct ProfileStub: Codable {
        let username: String
        let avatarEmoji: String?

        enum CodingKeys: String, CodingKey {
            case username
            case avatarEmoji = "avatar_emoji"
        }
    }

    /// Anonymous rows must not leak the author's name even though RLS returns the
    /// joined profile — the identity is dropped here, at the boundary.
    var identity: LightIdentity {
        isAnonymous
            ? LightIdentity(name: "익명", isAnonymous: true, avatarSeed: seed)
            : LightIdentity(name: profile?.username ?? "Scoor",
                            isAnonymous: false,
                            avatarSeed: seed)
    }

    /// LightIdentity.avatarSeed is documented as 1...9. Derived from the row id so
    /// a given reaction keeps the same avatar colour across reloads — Hashable's
    /// hashValue is seeded per-process and would flicker between launches.
    private var seed: Int {
        let byte = withUnsafeBytes(of: id.uuid) { $0.first ?? 0 }
        return Int(byte % 9) + 1
    }
}
