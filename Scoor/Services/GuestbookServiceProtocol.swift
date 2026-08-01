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
    /// Re-key entries when sign-in swaps the local account id (spec-13 §7).
    /// Without this the page owner's own guestbook empties out on sign-in for the
    /// same reason scores would — the rows point at the pre-login id.
    func reassignMessages(from oldUserId: UUID, to newUserId: UUID) async throws
}
