//
//  SocialPersistence.swift
//  Scoor
//
//  소셜 레이어의 SwiftData 영속 모델.
//  - 좋아요 / 댓글 / 월드 점수 / 팔로우를 로컬에 저장해 앱 재시작 후에도 유지.
//  - ScoreModel과 동일하게 ModelContainer 스키마에 등록되며, 추가만 하므로
//    라이트웨이트 마이그레이션으로 안전하게 반영된다.
//

import Foundation
import SwiftData

// MARK: - Like

/// 한 글(postId)에 대한 "내 좋아요" 상태. postId당 1행, 마지막 쓰기 승리.
@Model
final class LikeRecord {
    @Attribute(.unique) var postId: UUID
    var liked: Bool
    var updatedAt: Date

    init(postId: UUID, liked: Bool, updatedAt: Date = .now) {
        self.postId = postId
        self.liked = liked
        self.updatedAt = updatedAt
    }
}

// MARK: - Comment

/// 한 개의 댓글. 피드/월드 글 공통(postId로 구분).
@Model
final class CommentRecord {
    @Attribute(.unique) var id: UUID
    var postId: UUID
    var authorName: String
    var authorSeed: Int
    /// 작성자가 현재 사용자(나)인지 — 수정/삭제 권한.
    var isMine: Bool
    var text: String
    var createdAt: Date
    var editedAt: Date?

    init(
        id: UUID = UUID(),
        postId: UUID,
        authorName: String,
        authorSeed: Int,
        isMine: Bool,
        text: String,
        createdAt: Date = .now,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.postId = postId
        self.authorName = authorName
        self.authorSeed = authorSeed
        self.isMine = isMine
        self.text = text
        self.createdAt = createdAt
        self.editedAt = editedAt
    }

    func toValue() -> SocialComment {
        SocialComment(
            id: id,
            postId: postId,
            authorName: authorName,
            authorSeed: authorSeed,
            isMine: isMine,
            text: text,
            createdAt: createdAt,
            editedAt: editedAt
        )
    }
}

// MARK: - World Score (월드 토픽에 내가 매긴 점수)

/// 월드 토픽에 대한 내 점수 제출. (topicTitle, targetId) 조합으로 식별.
@Model
final class WorldScoreRecord {
    @Attribute(.unique) var key: String   // "\(topicTitle)#\(targetId)"
    var topicTitle: String
    var targetId: String                  // ScoorTarget.id ("match"/"team-TOT"/"mvp")
    var score: Int
    var comment: String?
    var updatedAt: Date

    init(topicTitle: String, targetId: String, score: Int, comment: String? = nil, updatedAt: Date = .now) {
        self.key = Self.makeKey(topicTitle: topicTitle, targetId: targetId)
        self.topicTitle = topicTitle
        self.targetId = targetId
        self.score = score
        self.comment = comment
        self.updatedAt = updatedAt
    }

    static func makeKey(topicTitle: String, targetId: String) -> String {
        "\(topicTitle)#\(targetId)"
    }
}

// MARK: - Follow (탐색에서 팔로우한 사용자)

@Model
final class FollowRecord {
    @Attribute(.unique) var userName: String
    var createdAt: Date

    init(userName: String, createdAt: Date = .now) {
        self.userName = userName
        self.createdAt = createdAt
    }
}
