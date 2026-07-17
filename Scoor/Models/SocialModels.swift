//
//  SocialModels.swift
//  Scoor
//
//  소셜 레이어(피드/월드/댓글/좋아요/탐색)의 값 타입 도메인.
//  - SwiftData @Model(영속)과 분리된 순수 값 타입 — 뷰/뷰모델이 다루는 통화(currency).
//  - FeedEntry / WorldPost / WorldTopic 등 기존 도메인은 FeedModels·WorldTopicModels에 정의.
//

import Foundation

// MARK: - Load Phase (로딩/빈/에러 상태 공용)

/// 비동기 컬렉션 로딩의 표준 상태기계 — Feed/World/Discover가 공유.
enum LoadPhase: Equatable {
    case idle
    case loading        // 최초 로딩 (스켈레톤)
    case loaded
    case empty          // 성공했지만 결과 0건
    case error(String)  // 사용자에게 보여줄 메시지

    var isLoading: Bool { self == .loading }
}

// MARK: - Comment (댓글)

/// 한 개의 댓글 — 피드/월드 글 공통.
struct SocialComment: Identifiable, Hashable {
    let id: UUID
    /// 댓글이 달린 글(FeedEntry.id 또는 WorldPost.id).
    let postId: UUID
    let authorName: String
    /// 아바타 색 시드(1~9).
    let authorSeed: Int
    /// 내가 쓴 댓글인지 — 수정/삭제 노출 여부.
    let isMine: Bool
    var text: String
    let createdAt: Date
    var editedAt: Date?

    var isEdited: Bool { editedAt != nil }
}

// MARK: - Discover (사용자 탐색)

/// 탐색 화면의 사용자 카드.
struct DiscoverUser: Identifiable, Hashable {
    let id: UUID
    let identity: LightIdentity
    /// 한 줄 소개 / 최근 감정 요약.
    let tagline: String
    /// 최근 평균 점수(0~100).
    let averageScore: Int
    /// 누적 글 수.
    let postCount: Int
    /// 팔로워 수(시드).
    let followers: Int
    /// 대표 지역 플래그.
    let regionFlag: String
    var isFollowing: Bool
}

/// 추천 콘텐츠 카드(트렌딩 글).
struct RecommendedContent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let glyph: String
    let score: Int
    let heatLabel: String
}

/// 탐색 화면 한 번에 로드되는 묶음.
struct DiscoverData: Hashable {
    var popularUsers: [DiscoverUser]
    var recommendedUsers: [DiscoverUser]
    var recommendedContent: [RecommendedContent]

    static let empty = DiscoverData(popularUsers: [], recommendedUsers: [], recommendedContent: [])

    var isEmpty: Bool {
        popularUsers.isEmpty && recommendedUsers.isEmpty && recommendedContent.isEmpty
    }
}

// MARK: - My Scoors (내가 점수 매긴 토픽/이슈/엔티티 이력)

/// 사용자가 월드 토픽/이슈/엔티티에 매긴 점수 1건. "My Scoors" 이력 목록의 행 모델.
/// - `WorldScoreRecord`(영속) 또는 Mock 저장소에서 값 타입으로 투영된다.
struct MyScoorEntry: Identifiable, Hashable {
    /// "\(topicTitle)#\(targetId)" — 토픽×대상 조합 고유키.
    let id: String
    let topicTitle: String
    let targetId: String
    let score: Int
    /// 점수 제출 시 남긴 한 줄 코멘트(= 사유).
    let reason: String?
    /// 마지막으로 점수를 매긴/수정한 시각.
    let createdAt: Date
}

// MARK: - Errors

enum SocialError: LocalizedError {
    case emptyComment
    case notFound
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyComment:            return "내용을 입력해주세요."
        case .notFound:                return "대상을 찾을 수 없어요."
        case .persistenceFailed(let m): return "저장 중 문제가 발생했어요. (\(m))"
        }
    }
}
