//
//  SwiftDataSocialService.swift
//  Scoor
//
//  소셜 레이어의 실제 영속 구현 — SwiftData 백엔드.
//  좋아요/댓글/월드 점수/팔로우를 로컬에 저장한다.
//  공개 콘텐츠는 Remote 서비스에서만 읽고, 서버가 없으면 빈 상태를 반환한다.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataSocialService: SocialServiceProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Feed

    func loadFeed(page: Int, pageSize: Int) async -> [FeedEntry] {
        []
    }

    // MARK: - World

    func loadTopics() async -> [WorldTopic] { [] }

    func loadWorldPosts(page: Int, pageSize: Int) async -> [WorldPost] {
        []
    }

    // MARK: - Likes

    func setLike(postId: UUID, liked: Bool) async throws {
        let descriptor = FetchDescriptor<LikeRecord>(predicate: #Predicate { $0.postId == postId })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.liked = liked
            existing.updatedAt = .now
        } else {
            modelContext.insert(LikeRecord(postId: postId, liked: liked))
        }
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }

    // MARK: - Comments

    func comments(for postId: UUID) async -> [SocialComment] {
        let descriptor = FetchDescriptor<CommentRecord>(
            predicate: #Predicate { $0.postId == postId },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return ((try? modelContext.fetch(descriptor)) ?? []).map { $0.toValue() }
    }

    func commentCount(for postId: UUID) -> Int {
        let descriptor = FetchDescriptor<CommentRecord>(predicate: #Predicate { $0.postId == postId })
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    @discardableResult
    func addComment(postId: UUID, text: String, authorName: String, authorSeed: Int) async throws -> SocialComment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }
        let record = CommentRecord(
            postId: postId, authorName: authorName, authorSeed: authorSeed,
            isMine: true, text: trimmed
        )
        modelContext.insert(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
        return record.toValue()
    }

    func editComment(id: UUID, newText: String) async throws {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }
        let descriptor = FetchDescriptor<CommentRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { throw SocialError.notFound }
        record.text = trimmed
        record.editedAt = .now
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }

    func deleteComment(id: UUID) async throws {
        let descriptor = FetchDescriptor<CommentRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { throw SocialError.notFound }
        modelContext.delete(record)
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }

    // MARK: - World score

    func submitWorldScore(topicTitle: String, targetId: String, score: Int, comment: String?) async throws {
        let clamped = min(100, max(0, score))
        let key = WorldScoreRecord.makeKey(topicTitle: topicTitle, targetId: targetId)
        let descriptor = FetchDescriptor<WorldScoreRecord>(predicate: #Predicate { $0.key == key })
        if let existing = try modelContext.fetch(descriptor).first {
            existing.score = clamped
            existing.comment = comment
            existing.updatedAt = .now
        } else {
            modelContext.insert(WorldScoreRecord(topicTitle: topicTitle, targetId: targetId, score: clamped, comment: comment))
        }
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }

    func myWorldScore(topicTitle: String, targetId: String) -> Int? {
        let key = WorldScoreRecord.makeKey(topicTitle: topicTitle, targetId: targetId)
        let descriptor = FetchDescriptor<WorldScoreRecord>(predicate: #Predicate { $0.key == key })
        return (try? modelContext.fetch(descriptor))?.first?.score
    }

    func myWorldScores() async -> [MyScoorEntry] {
        let descriptor = FetchDescriptor<WorldScoreRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        return rows.map {
            MyScoorEntry(
                id: $0.key,
                topicTitle: $0.topicTitle,
                targetId: $0.targetId,
                score: $0.score,
                reason: $0.comment,
                createdAt: $0.updatedAt
            )
        }
    }

    // MARK: - Discover

    func loadDiscover() async -> DiscoverData {
        .empty
    }

    func isFollowing(_ userName: String) -> Bool {
        let descriptor = FetchDescriptor<FollowRecord>(predicate: #Predicate { $0.userName == userName })
        return ((try? modelContext.fetchCount(descriptor)) ?? 0) > 0
    }

    func setFollowing(_ following: Bool, userName: String) async throws {
        let descriptor = FetchDescriptor<FollowRecord>(predicate: #Predicate { $0.userName == userName })
        let existing = try modelContext.fetch(descriptor)
        if following {
            if existing.isEmpty { modelContext.insert(FollowRecord(userName: userName)) }
        } else {
            for r in existing { modelContext.delete(r) }
        }
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }

    // MARK: - Account lifecycle

    func deleteAllLocalData() async throws {
        try modelContext.delete(model: LikeRecord.self)
        try modelContext.delete(model: CommentRecord.self)
        try modelContext.delete(model: WorldScoreRecord.self)
        try modelContext.delete(model: FollowRecord.self)
        try modelContext.save()
        NotificationCenter.default.post(name: .scoorSocialStoreDidChange, object: nil)
    }
}
