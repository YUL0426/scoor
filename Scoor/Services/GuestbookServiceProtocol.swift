//
//  GuestbookServiceProtocol.swift
//  Scoor
//

import Foundation

protocol GuestbookServiceProtocol {
    func getMessages(recipientId: UUID, includePrivate: Bool) async -> [GuestbookMessage]
    func postMessage(authorId: UUID, recipientId: UUID, content: String, isPrivate: Bool) async throws
}
