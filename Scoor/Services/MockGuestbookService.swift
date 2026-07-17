//
//  MockGuestbookService.swift
//  Scoor
//

import Foundation

final class MockGuestbookService: GuestbookServiceProtocol {
    private var storage: [GuestbookMessage] = []

    /// Use for previews: pre-fill with sample messages.
    init(seedMessages: [GuestbookMessage] = []) {
        storage = seedMessages.sorted { $0.createdAt > $1.createdAt }
    }

    func getMessages(recipientId: UUID, includePrivate: Bool) async -> [GuestbookMessage] {
        let filtered = storage.filter { $0.recipientId == recipientId }
        if includePrivate { return filtered.sorted { $0.createdAt > $1.createdAt } }
        return filtered.filter { !$0.isPrivate }.sorted { $0.createdAt > $1.createdAt }
    }

    func postMessage(authorId: UUID, recipientId: UUID, content: String, isPrivate: Bool) async throws {
        let message = GuestbookMessage(
            authorId: authorId,
            recipientId: recipientId,
            content: content,
            isPrivate: isPrivate
        )
        storage.append(message)
    }

    func deleteMessage(id: UUID) async throws {
        storage.removeAll { $0.id == id }
    }

    func deleteAllMessages() async throws {
        storage.removeAll()
    }
}
