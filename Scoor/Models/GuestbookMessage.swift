//
//  GuestbookMessage.swift
//  Scoor
//

import Foundation

struct GuestbookMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let authorId: UUID
    let recipientId: UUID
    var content: String
    var isPrivate: Bool
    let createdAt: Date

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
}
