//
//  SocialServiceTests.swift
//  ScoorTests
//
//  소셜 레이어(좋아요/댓글/월드 점수/팔로우/탐색) 유닛 테스트.
//  - MockSocialService는 SwiftDataSocialService와 동일한 SocialSeed 로직을 공유하므로
//    시드/오버레이/페이지네이션의 핵심 동작을 결정론적으로 검증한다.
//

import XCTest
@testable import Scoor

@MainActor
final class SocialServiceTests: XCTestCase {

    // MARK: - Pagination & determinism

    func testFeedPaginationReturnsStableDeterministicIDs() async {
        let service = MockSocialService()
        let page0a = await service.loadFeed(page: 0, pageSize: 8)
        let page0b = await service.loadFeed(page: 0, pageSize: 8)
        XCTAssertEqual(page0a.count, 8)
        XCTAssertEqual(page0a.map(\.id), page0b.map(\.id), "같은 페이지는 항상 같은 id를 반환해야 한다")

        let page1 = await service.loadFeed(page: 1, pageSize: 8)
        XCTAssertEqual(page1.count, 8)
        let overlap = Set(page0a.map(\.id)).intersection(page1.map(\.id))
        XCTAssertTrue(overlap.isEmpty, "다음 페이지는 새로운(합성) id를 가져야 한다")
    }

    func testDeterministicUUIDIsStable() {
        let a = SocialSeed.deterministicUUID("feed::1::0::abc")
        let b = SocialSeed.deterministicUUID("feed::1::0::abc")
        let c = SocialSeed.deterministicUUID("feed::1::1::abc")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Likes (영속 오버레이)

    func testSetLikeReflectedInNextLoad() async throws {
        let service = MockSocialService()
        let first = await service.loadFeed(page: 0, pageSize: 8)
        guard let target = first.first else { return XCTFail("no entries") }
        let wasLiked = target.reactions.likedByMe
        let baseLikes = target.reactions.likes

        try await service.setLike(postId: target.id, liked: !wasLiked)
        let reloaded = await service.loadFeed(page: 0, pageSize: 8)
        let updated = try XCTUnwrap(reloaded.first { $0.id == target.id })

        XCTAssertEqual(updated.reactions.likedByMe, !wasLiked)
        let expected = wasLiked ? baseLikes - 1 : baseLikes + 1
        XCTAssertEqual(updated.reactions.likes, expected, "좋아요 수가 토글 방향대로 1 변해야 한다")
    }

    func testLikeToggleTwiceReturnsToBaseline() async throws {
        let service = MockSocialService()
        let first = await service.loadFeed(page: 0, pageSize: 8)
        guard let target = first.first else { return XCTFail("no entries") }
        let baseLikes = target.reactions.likes
        let wasLiked = target.reactions.likedByMe

        try await service.setLike(postId: target.id, liked: !wasLiked)
        try await service.setLike(postId: target.id, liked: wasLiked)
        let reloaded = await service.loadFeed(page: 0, pageSize: 8)
        let updated = try XCTUnwrap(reloaded.first { $0.id == target.id })
        XCTAssertEqual(updated.reactions.likes, baseLikes)
        XCTAssertEqual(updated.reactions.likedByMe, wasLiked)
    }

    // MARK: - Comments CRUD

    func testCommentCreateEditDelete() async throws {
        let service = MockSocialService()
        let entries = await service.loadFeed(page: 0, pageSize: 8)
        let postId = try XCTUnwrap(entries.first?.id)

        XCTAssertEqual(service.commentCount(for: postId), 0)

        // 작성
        let created = try await service.addComment(postId: postId, text: "첫 댓글", authorName: "나", authorSeed: 1)
        XCTAssertEqual(service.commentCount(for: postId), 1)
        XCTAssertTrue(created.isMine)

        // 댓글 수가 다음 로드의 카드 카운트에 반영
        let reloaded = await service.loadFeed(page: 0, pageSize: 8)
        let card = try XCTUnwrap(reloaded.first { $0.id == postId })
        let baseComments = entries.first { $0.id == postId }!.reactions.comments
        XCTAssertEqual(card.reactions.comments, baseComments + 1)

        // 수정
        try await service.editComment(id: created.id, newText: "수정된 댓글")
        let afterEdit = await service.comments(for: postId)
        XCTAssertEqual(afterEdit.first?.text, "수정된 댓글")
        XCTAssertNotNil(afterEdit.first?.editedAt)

        // 삭제
        try await service.deleteComment(id: created.id)
        XCTAssertEqual(service.commentCount(for: postId), 0)
    }

    func testEmptyCommentRejected() async {
        let service = MockSocialService()
        let postId = UUID()
        do {
            _ = try await service.addComment(postId: postId, text: "   ", authorName: "나", authorSeed: 1)
            XCTFail("빈 댓글은 거부되어야 한다")
        } catch {
            XCTAssertTrue(error is SocialError)
        }
    }

    // MARK: - World score

    func testWorldScoreSubmitAndClamp() async throws {
        let service = MockSocialService()
        XCTAssertNil(service.myWorldScore(topicTitle: "토트넘 vs 아스널", targetId: "match"))

        try await service.submitWorldScore(topicTitle: "토트넘 vs 아스널", targetId: "match", score: 142, comment: "최고")
        XCTAssertEqual(service.myWorldScore(topicTitle: "토트넘 vs 아스널", targetId: "match"), 100, "0~100 범위로 클램프되어야 한다")

        try await service.submitWorldScore(topicTitle: "토트넘 vs 아스널", targetId: "match", score: 73, comment: nil)
        XCTAssertEqual(service.myWorldScore(topicTitle: "토트넘 vs 아스널", targetId: "match"), 73, "재작성 시 마지막 값으로 갱신")
    }

    // MARK: - Discover & follow

    func testDiscoverProvidesUsersAndContent() async {
        let service = MockSocialService()
        let data = await service.loadDiscover()
        XCTAssertFalse(data.popularUsers.isEmpty)
        XCTAssertFalse(data.recommendedContent.isEmpty)
        // 인기 사용자는 팔로워 내림차순
        let followers = data.popularUsers.map(\.followers)
        XCTAssertEqual(followers, followers.sorted(by: >))
    }

    func testFollowTogglesAndFiltersRecommendations() async throws {
        let service = MockSocialService()
        let before = await service.loadDiscover()
        let user = try XCTUnwrap(before.recommendedUsers.first)
        XCTAssertFalse(service.isFollowing(user.identity.name))

        try await service.setFollowing(true, userName: user.identity.name)
        XCTAssertTrue(service.isFollowing(user.identity.name))

        let after = await service.loadDiscover()
        XCTAssertFalse(after.recommendedUsers.contains { $0.identity.name == user.identity.name },
                       "팔로우한 사용자는 추천에서 제외되어야 한다")
        XCTAssertTrue(after.popularUsers.contains { $0.identity.name == user.identity.name && $0.isFollowing },
                      "인기 목록에는 남되 isFollowing=true 여야 한다")
    }
}
