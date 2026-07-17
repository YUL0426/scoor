//
//  GuestbookServiceProtocol.swift
//  Scoor
//

import Foundation

protocol GuestbookServiceProtocol {
    func getMessages(recipientId: UUID, includePrivate: Bool) async -> [GuestbookMessage]
    func postMessage(authorId: UUID, recipientId: UUID, content: String, isPrivate: Bool) async throws
    /// Remove a guestbook entry by id (page-owner moderation). BUG-010.
    func deleteMessage(id: UUID) async throws
    /// Remove every stored message (account deletion, P0-4).
    func deleteAllMessages() async throws
}
