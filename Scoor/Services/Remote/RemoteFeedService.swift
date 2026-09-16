//
//  RemoteFeedService.swift
//  Scoor
//
//  Feed 탭의 서버 데이터 경로 (spec-13 §3.3).
//
//  Feed는 그동안 `SocialSeed`가 합성한 가짜 글을 보여줬다. World가 그랬듯이
//  (RemoteWorldService), 이 타입이 그 자리를 실제 저장소로 바꾼다.
//
//  `SocialServiceProtocol`을 따르지 않고 별도 타입인 이유는 RemoteWorldService와
//  같다: 그 프로토콜은 댓글 작성자를 `authorSeed`(시드 데이터의 아바타 색)로
//  식별하는데, 서버에서 작성자는 실제 계정이다. 시드용 식별자를 서버 경로에
//  끌고 오면 두 모델이 서로를 오염시킨다.
//
//  실패를 삼키지 않는다. 개인 저널링은 오프라인에서도 조용히 동작해야 하지만
//  (spec-13 §5), 피드는 명시적으로 온라인 기능이라 못 불러오면 못 불러왔다고
//  말해야 한다 — 실패했을 때 시드로 되돌아가면 가짜 콘텐츠가 되살아난다.
//

import Foundation

@MainActor
protocol HomeFeedPublishing {
    var isAvailable: Bool { get }
    func isDailyScoreShared(on date: Date) async throws -> Bool
    func setDailyScore(_ score: Score, shared: Bool) async throws
}

@MainActor
final class RemoteFeedService: HomeFeedPublishing {

    private let client: SupabaseHTTPClient
    private let currentUserID: () -> UUID?

    init(client: SupabaseHTTPClient, currentUserID: @escaping () -> UUID?) {
        self.client = client
        self.currentUserID = currentUserID
    }

    var isAvailable: Bool { currentUserID() != nil }

    // MARK: - Read

    /// 최신순 한 페이지. `feed_posts` 뷰를 읽는다 — topics_feed와 같은 이유로
    /// 조인/집계를 DB에서 끝내 왕복을 한 번으로 줄인다.
    func loadFeed(page: Int, pageSize: Int) async throws -> [FeedEntry] {
        let rows: [FeedPostRow] = try await client.send(
            .select("feed_posts",
                    order: "created_at.desc",
                    limit: pageSize,
                    offset: page * pageSize),
            as: [FeedPostRow].self
        )
        return rows.map { $0.toDomain() }
    }

    func loadReposts(page: Int, pageSize: Int) async throws -> [FeedEntry] {
        guard currentUserID() != nil else { throw APIError.unauthorized }
        let rows: [FeedPostRow] = try await client.send(
            .select("feed_posts",
                    filters: ["reposted_by_me": "eq.true"],
                    order: "reposted_at.desc,id.desc", limit: pageSize, offset: page * pageSize),
            as: [FeedPostRow].self
        )
        return rows.map { $0.toDomain() }
    }

    func setRepost(postId: UUID, reposted: Bool) async throws {
        guard let userId = currentUserID() else { throw APIError.unauthorized }
        if reposted {
            try await client.send(try .upsert("post_reposts",
                values: [PostLikeRow(postId: postId, userId: userId)], onConflict: "post_id,user_id"))
        } else {
            try await client.send(.delete("post_reposts", filters: [
                "post_id": SupabaseRequest.eq(postId.uuidString.lowercased()),
                "user_id": SupabaseRequest.eq(userId.uuidString.lowercased())
            ]))
        }
        NotificationCenter.default.post(name: .scoorRepostsDidChange, object: nil)
    }

    // MARK: - Daily score sharing

    func isDailyScoreShared(on date: Date) async throws -> Bool {
        guard let userId = currentUserID() else { return false }
        let rows: [ExistingDailyPostRow] = try await client.send(
            .select(
                "posts",
                columns: "id",
                filters: dailyPostFilters(userId: userId, date: date),
                limit: 1
            ),
            as: [ExistingDailyPostRow].self
        )
        return !rows.isEmpty
    }

    /// Keeps one active home post per user/day. Editing a shared score updates
    /// the existing post; turning sharing off soft-deletes it.
    func setDailyScore(_ score: Score, shared: Bool) async throws {
        guard let userId = currentUserID(), userId == score.userId else {
            throw APIError.unauthorized
        }
        let filters = dailyPostFilters(userId: userId, date: score.date)
        let existing: [ExistingDailyPostRow] = try await client.send(
            .select("posts", columns: "id", filters: filters, limit: 1),
            as: [ExistingDailyPostRow].self
        )

        if shared {
            let message = score.reason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !message.isEmpty else { throw HomeFeedPublishError.reasonRequired }
            let values = DailyPostWrite(
                authorId: userId,
                score: score.value,
                message: String(message.prefix(280)),
                primaryMood: (score.mood ?? Self.fallbackMood(for: score.value)).rawValue,
                sourceDay: Self.dayString(score.date)
            )
            if let post = existing.first {
                try await client.send(try .update(
                    "posts",
                    values: values,
                    filters: ["id": SupabaseRequest.eq(post.id.uuidString.lowercased())]
                ))
            } else {
                try await client.send(try .insert("posts", values: values))
            }
        } else if let post = existing.first {
            try await client.send(try .update(
                "posts",
                values: DailyPostSoftDelete(deletedAt: Date()),
                filters: ["id": SupabaseRequest.eq(post.id.uuidString.lowercased())]
            ))
        }

        NotificationCenter.default.post(name: .scoorHomeFeedDidChange, object: nil)
    }

    private func dailyPostFilters(userId: UUID, date: Date) -> [String: String] {
        [
            "author_id": SupabaseRequest.eq(userId.uuidString.lowercased()),
            "source_day": SupabaseRequest.eq(Self.dayString(date)),
            "is_official": SupabaseRequest.eq("false"),
            "deleted_at": "is.null",
        ]
    }

    private static func dayString(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func fallbackMood(for score: Int) -> Mood {
        if score >= 80 { return .happy }
        if score <= 35 { return .burnout }
        return .calm
    }

    // MARK: - Likes

    func setLike(postId: UUID, liked: Bool) async throws {
        guard let userId = currentUserID() else { throw APIError.unauthorized }
        let post = postId.uuidString.lowercased()
        let user = userId.uuidString.lowercased()
        if liked {
            // upsert라 연타/재시도가 중복 행을 만들지 않는다.
            try await client.send(
                try .upsert("post_likes",
                            values: [PostLikeRow(postId: postId, userId: userId)],
                            onConflict: "post_id,user_id")
            )
        } else {
            try await client.send(
                .delete("post_likes", filters: [
                    "post_id": SupabaseRequest.eq(post),
                    "user_id": SupabaseRequest.eq(user),
                ])
            )
        }
    }

    // MARK: - Comments

    func comments(for postId: UUID) async throws -> [SocialComment] {
        let rows: [CommentRow] = try await client.send(
            .select("comments",
                    columns: "id,post_id,author_id,text,is_anonymous,created_at,edited_at,profiles(username)",
                    filters: ["post_id": SupabaseRequest.eq(postId.uuidString.lowercased())],
                    order: "created_at.asc"),
            as: [CommentRow].self
        )
        let me = currentUserID()
        return rows.map { $0.toDomain(currentUserID: me) }
    }

    @discardableResult
    func addComment(postId: UUID, text: String) async throws -> SocialComment {
        guard let userId = currentUserID() else { throw APIError.unauthorized }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }

        let rows: [CommentRow] = try await client.send(
            try .insert("comments",
                        values: [NewCommentRow(postId: postId, authorId: userId, text: trimmed)],
                        returning: true),
            as: [CommentRow].self
        )
        guard let row = rows.first else { throw APIError.decoding("comment insert returned no row") }
        return row.toDomain(currentUserID: userId)
    }

    func editComment(id: UUID, newText: String) async throws {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }
        try await client.send(
            try .update("comments",
                        values: CommentEdit(text: trimmed, editedAt: Date()),
                        filters: ["id": SupabaseRequest.eq(id.uuidString.lowercased())])
        )
    }

    /// soft delete — 모더레이션 이력과 신고 참조가 남아야 한다.
    func deleteComment(id: UUID) async throws {
        try await client.send(
            try .update("comments",
                        values: CommentSoftDelete(deletedAt: Date()),
                        filters: ["id": SupabaseRequest.eq(id.uuidString.lowercased())])
        )
    }
}

enum HomeFeedPublishError: LocalizedError, Equatable {
    case reasonRequired

    var errorDescription: String? {
        switch self {
        case .reasonRequired: return String(localized: "홈에 공유하려면 오늘의 이유를 입력해주세요.")
        }
    }
}

extension Notification.Name {
    static let scoorRepostsDidChange = Notification.Name("scoor.repostsDidChange")
    static let scoorHomeFeedDidChange = Notification.Name("scoor.homeFeedDidChange")
}

// MARK: - Wire models

/// `public.feed_posts` 한 행.
struct FeedPostRow: Decodable {
    let id: UUID
    let isOfficial: Bool
    let score: Int
    let message: String
    let primaryMood: String
    let extraMoods: [String]
    let weather: String?
    let isAnonymous: Bool
    let countryCode: String?
    let city: String?
    let createdAt: Date
    let authorName: String?
    let authorEmoji: String?
    let authorId: UUID?
    let likesCount: Int
    let commentsCount: Int
    let likedByMe: Bool
    let repostsCount: Int?
    let repostedByMe: Bool?

    enum CodingKeys: String, CodingKey {
        case id, score, message, weather, city
        case isOfficial = "is_official"
        case primaryMood = "primary_mood"
        case extraMoods = "extra_moods"
        case isAnonymous = "is_anonymous"
        case countryCode = "country_code"
        case createdAt = "created_at"
        case authorName = "author_name"
        case authorEmoji = "author_emoji"
        case authorId = "author_id"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case likedByMe = "liked_by_me"
        case repostsCount = "reposts_count"
        case repostedByMe = "reposted_by_me"
    }

    func toDomain() -> FeedEntry {
        let name = authorName ?? String(localized: "익명")
        return FeedEntry(
            id: id,
            identity: LightIdentity(name: name,
                                    isAnonymous: authorName == nil,
                                    avatarSeed: AvatarSeed.from(name)),
            countryFlag: CountryFlag.emoji(countryCode) ?? "",
            city: city ?? "",
            postedAt: createdAt,
            score: score,
            message: message,
            primaryMood: Mood(rawValue: primaryMood) ?? .calm,
            extraTags: extraMoods.compactMap(Mood.init(rawValue:)),
            weather: weather.flatMap(Weather.init(rawValue:)),
            reactions: PostReactions(
                likes: likesCount,
                comments: commentsCount,
                reposts: repostsCount ?? 0,
                empathyTotal: 0,
                likedByMe: likedByMe,
                empathyByMe: nil,
                repostedByMe: repostedByMe ?? false
            ),
            isOfficial: isOfficial,
            authorId: authorId
        )
    }
}

private struct PostLikeRow: Encodable {
    let postId: UUID
    let userId: UUID
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

private struct ExistingDailyPostRow: Decodable {
    let id: UUID
}

private struct DailyPostWrite: Encodable {
    let authorId: UUID
    let score: Int
    let message: String
    let primaryMood: String
    let sourceDay: String
    let isOfficial = false
    let isAnonymous = false
    let extraMoods: [String] = []

    enum CodingKeys: String, CodingKey {
        case score, message
        case authorId = "author_id"
        case primaryMood = "primary_mood"
        case sourceDay = "source_day"
        case isOfficial = "is_official"
        case isAnonymous = "is_anonymous"
        case extraMoods = "extra_moods"
    }
}

private struct DailyPostSoftDelete: Encodable {
    let deletedAt: Date
    enum CodingKeys: String, CodingKey { case deletedAt = "deleted_at" }
}

private struct NewCommentRow: Encodable {
    let postId: UUID
    let authorId: UUID
    let text: String
    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case authorId = "author_id"
        case text
    }
}

private struct CommentEdit: Encodable {
    let text: String
    let editedAt: Date
    enum CodingKeys: String, CodingKey {
        case text
        case editedAt = "edited_at"
    }
}

private struct CommentSoftDelete: Encodable {
    let deletedAt: Date
    enum CodingKeys: String, CodingKey { case deletedAt = "deleted_at" }
}

struct CommentRow: Decodable {
    struct Author: Decodable { let username: String? }

    let id: UUID
    let postId: UUID
    let authorId: UUID
    let text: String
    let isAnonymous: Bool
    let createdAt: Date
    let editedAt: Date?
    let profiles: Author?

    enum CodingKeys: String, CodingKey {
        case id, text, profiles
        case postId = "post_id"
        case authorId = "author_id"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case editedAt = "edited_at"
    }

    func toDomain(currentUserID: UUID?) -> SocialComment {
        let name = isAnonymous ? String(localized: "익명") : (profiles?.username ?? String(localized: "이름 없음"))
        return SocialComment(
            id: id,
            postId: postId,
            authorName: name,
            authorSeed: AvatarSeed.from(name),
            isMine: authorId == currentUserID,
            text: text,
            createdAt: createdAt,
            editedAt: editedAt,
            authorId: authorId
        )
    }
}

// MARK: - Small helpers

/// 아바타 색 시드(1~9). 시드 데이터에서는 저자마다 고정 숫자를 들고 있었지만
/// 서버 글에는 그런 필드가 없으므로 이름에서 결정적으로 만든다 — 같은 사람은
/// 화면이 바뀌어도 같은 색이어야 한다.
enum AvatarSeed {
    static func from(_ name: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % 9) + 1
    }
}

/// ISO 3166-1 alpha-2 → 국기 이모지. 지역 표시는 전적으로 선택 사항이라
/// 값이 없거나 형식이 어긋나면 조용히 비운다.
enum CountryFlag {
    static func emoji(_ code: String?) -> String? {
        guard let code, code.count == 2 else { return nil }
        let base: UInt32 = 127397
        var result = ""
        for scalar in code.uppercased().unicodeScalars {
            guard let flagScalar = UnicodeScalar(base + scalar.value) else { return nil }
            result.unicodeScalars.append(flagScalar)
        }
        return result
    }
}
