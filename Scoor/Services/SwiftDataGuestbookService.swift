//
//  SwiftDataGuestbookService.swift
//  Scoor
//
//  방명록의 실제 영속 구현 — SwiftData 백엔드 (P0-6).
//  MockGuestbookService와 동일 계약이지만 앱 재시작 후에도 메시지가 유지된다.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataGuestbookService: GuestbookServiceProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func getMessages(recipientId: UUID, includePrivate: Bool) async -> [GuestbookMessage] {
        let descriptor = FetchDescriptor<GuestbookRecord>(
            predicate: #Predicate { $0.recipientId == recipientId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = (try? modelContext.fetch(descriptor)) ?? []
        let messages = rows.map { $0.toValue() }
        return includePrivate ? messages : messages.filter { !$0.isPrivate }
    }

    func postMessage(authorId: UUID, recipientId: UUID, content: String, isPrivate: Bool) async throws {
        let record = GuestbookRecord(
            authorId: authorId,
            recipientId: recipientId,
            content: content,
            isPrivate: isPrivate
        )
        modelContext.insert(record)
        try modelContext.save()
    }

    func deleteMessage(id: UUID) async throws {
        let descriptor = FetchDescriptor<GuestbookRecord>(predicate: #Predicate { $0.id == id })
        guard let record = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(record)
        try modelContext.save()
    }

    func deleteAllMessages() async throws {
        try modelContext.delete(model: GuestbookRecord.self)
        try modelContext.save()
    }

    /// Re-key both sides: entries the user received (recipient) and ones they left
    /// on their own page (author) — spec-13 §7.
    func reassignMessages(from oldUserId: UUID, to newUserId: UUID) async throws {
        guard oldUserId != newUserId else { return }

        let received = try modelContext.fetch(
            FetchDescriptor<GuestbookRecord>(predicate: #Predicate { $0.recipientId == oldUserId })
        )
        for record in received { record.recipientId = newUserId }

        let written = try modelContext.fetch(
            FetchDescriptor<GuestbookRecord>(predicate: #Predicate { $0.authorId == oldUserId })
        )
        for record in written { record.authorId = newUserId }

        guard !received.isEmpty || !written.isEmpty else { return }
        try modelContext.save()
    }
}
