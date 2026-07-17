//
//  SocialServiceProtocol.swift
//  Scoor
//
//  소셜 레이어(피드/월드/좋아요/댓글/탐색)의 데이터 계약.
//  - ScoreServiceProtocol과 동일하게 Mock + SwiftData 구현을 드롭인 교체 가능.
//  - 백엔드 도입 시 동일 프로토콜로 네트워크 구현만 추가하면 된다.
//  - @MainActor: SwiftData mainContext 사용 및 UI 상태 일관성.
//

import Foundation

@MainActor
protocol SocialServiceProtocol {

    // MARK: Feed
    /// 페이지 단위 피드 로드(영속 좋아요/댓글 수 반영됨).
    func loadFeed(page: Int, pageSize: Int) async -> [FeedEntry]

    // MARK: World
    func loadTopics() async -> [WorldTopic]
    func loadWorldPosts(page: Int, pageSize: Int) async -> [WorldPost]

    // MARK: Likes
    /// 좋아요 토글 영속. 다음 로드 시 시드 위에 덧입혀진다.
    func setLike(postId: UUID, liked: Bool) async throws

    // MARK: Comments
    func comments(for postId: UUID) async -> [SocialComment]
    func commentCount(for postId: UUID) -> Int
    @discardableResult
    func addComment(postId: UUID, text: String, authorName: String, authorSeed: Int) async throws -> SocialComment
    func editComment(id: UUID, newText: String) async throws
    func deleteComment(id: UUID) async throws

    // MARK: World score
    func submitWorldScore(topicTitle: String, targetId: String, score: Int, comment: String?) async throws
    func myWorldScore(topicTitle: String, targetId: String) -> Int?
    /// 내가 점수 매긴 모든 토픽/이슈/엔티티 이력(최신순). "My Scoors" 화면용.
    func myWorldScores() async -> [MyScoorEntry]

    // MARK: Discover
    func loadDiscover() async -> DiscoverData
    func isFollowing(_ userName: String) -> Bool
    func setFollowing(_ following: Bool, userName: String) async throws
}

// MARK: - Notifications

extension Notification.Name {
    /// 소셜 영속 저장소 변경(좋아요/댓글/팔로우) 시 브로드캐스트.
    static let scoorSocialStoreDidChange = Notification.Name("scoor.socialStoreDidChange")
}
