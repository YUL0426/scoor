//
//  GuestbookPersistence.swift
//  Scoor
//
//  SwiftData 영속 모델 — 방명록. MockGuestbookService(인메모리)가 앱 재시작 시
//  사용자가 쓴 방명록을 전부 유실하던 문제(P0-6)를 해결한다. SocialPersistence의
//  레코드들과 동일하게 ModelContainer 스키마에 추가만 하므로 라이트웨이트
//  마이그레이션으로 안전하게 반영된다.
//

import Foundation
import SwiftData

@Model
final class GuestbookRecord {
    @Attribute(.unique) var id: UUID
    var authorId: UUID
    var recipientId: UUID
    var content: String
    var isPrivate: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        authorId: UUID,
        recipientId: UUID,
        content: String,
        isPrivate: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.authorId = authorId
        self.recipientId = recipientId
        self.content = content
        self.isPrivate = isPrivate
        self.createdAt = createdAt
    }

    func toValue() -> GuestbookMessage {
        GuestbookMessage(
            id: id,
            authorId: authorId,
            recipientId: recipientId,
            content: content,
            isPrivate: isPrivate,
            createdAt: createdAt
        )
    }
}
