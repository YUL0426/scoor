//
//  MockSocialService.swift
//  Scoor
//
//  소셜 레이어의 인메모리 구현 — SwiftUI 프리뷰 / 유닛 테스트 / 기본 AppServices용.
//  영속은 안 하지만 좋아요 토글·댓글 CRUD·팔로우가 세션 내에서 실제로 동작한다.
//

import Foundation

@MainActor
final class MockSocialService: SocialServiceProtocol {

    private var likes: [UUID: Bool] = [:]
    private var commentsStore: [UUID: [SocialComment]] = [:]
    private var worldScores: [String: MyScoorEntry] = [:]
    private var follows: Set<String> = []

    nonisolated init() {}

    private func extraCommentCounts() -> [UUID: Int] {
        commentsStore.mapValues { $0.count }
    }

    func loadFeed(page: Int, pageSize: Int) async -> [FeedEntry] {
        let raw = SocialSeed.feedPage(page: page, pageSize: pageSize)
        return SocialSeed.applyFeedOverlays(raw, likeMap: likes, extraComments: extraCommentCounts())
    }

    func loadTopics() async -> [WorldTopic] { SocialSeed.topics }

    func loadWorldPosts(page: Int, pageSize: Int) async -> [WorldPost] {
        let raw = SocialSeed.worldPostsPage(page: page, pageSize: pageSize)
        return SocialSeed.applyWorldOverlays(raw, likeMap: likes, extraComments: extraCommentCounts())
    }

    func setLike(postId: UUID, liked: Bool) async throws {
        likes[postId] = liked
    }

    func comments(for postId: UUID) async -> [SocialComment] {
        (commentsStore[postId] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    func commentCount(for postId: UUID) -> Int {
        commentsStore[postId]?.count ?? 0
    }

    @discardableResult
    func addComment(postId: UUID, text: String, authorName: String, authorSeed: Int) async throws -> SocialComment {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }
        let comment = SocialComment(
            id: UUID(), postId: postId, authorName: authorName, authorSeed: authorSeed,
            isMine: true, text: trimmed, createdAt: .now, editedAt: nil
        )
        commentsStore[postId, default: []].append(comment)
        return comment
    }

    func editComment(id: UUID, newText: String) async throws {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialError.emptyComment }
        for (post, list) in commentsStore {
            if let idx = list.firstIndex(where: { $0.id == id }) {
                commentsStore[post]?[idx].text = trimmed
                commentsStore[post]?[idx].editedAt = .now
                return
            }
        }
        throw SocialError.notFound
    }

    func deleteComment(id: UUID) async throws {
        for (post, list) in commentsStore {
            if list.contains(where: { $0.id == id }) {
                commentsStore[post]?.removeAll { $0.id == id }
                return
            }
        }
        throw SocialError.notFound
    }

    func submitWorldScore(topicTitle: String, targetId: String, score: Int, comment: String?) async throws {
        let key = WorldScoreRecord.makeKey(topicTitle: topicTitle, targetId: targetId)
        worldScores[key] = MyScoorEntry(
            id: key,
            topicTitle: topicTitle,
            targetId: targetId,
            score: min(100, max(0, score)),
            reason: comment,
            createdAt: Date()
        )
    }

    func myWorldScore(topicTitle: String, targetId: String) -> Int? {
        worldScores[WorldScoreRecord.makeKey(topicTitle: topicTitle, targetId: targetId)]?.score
    }

    func myWorldScores() async -> [MyScoorEntry] {
        worldScores.values.sorted { $0.createdAt > $1.createdAt }
    }

    func loadDiscover() async -> DiscoverData {
        let (popular, recommended) = SocialSeed.discoverUsers(following: follows)
        return DiscoverData(
            popularUsers: popular,
            recommendedUsers: recommended,
            recommendedContent: SocialSeed.recommendedContent()
        )
    }

    func isFollowing(_ userName: String) -> Bool { follows.contains(userName) }

    func setFollowing(_ following: Bool, userName: String) async throws {
        if following { follows.insert(userName) } else { follows.remove(userName) }
    }

    func deleteAllLocalData() async throws {
        likes.removeAll()
        commentsStore.removeAll()
        worldScores.removeAll()
        follows.removeAll()
    }
}
