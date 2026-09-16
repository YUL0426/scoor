import Foundation

struct TopicProposal: Codable, Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let category: String
    let kind: String
    let sourceURL: String?
    let low: String
    let high: String
    let status: String
    let revision: Int
    let reason: String?
    let topicID: UUID?
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, category, kind, status, revision
        case sourceURL = "source_url", low = "score_low_label", high = "score_high_label"
        case reason = "review_reason", topicID = "topic_id"
    }
    var statusLabel: String { TopicProposal.statusLabel(status) }
    var editable: Bool { ["pending", "changes_requested"].contains(status) }
    static func statusLabel(_ status: String) -> String {
        switch status {
        case "pending": return String(localized: "검토 중")
        case "changes_requested": return String(localized: "수정 요청")
        case "approved": return String(localized: "게시됨")
        case "rejected": return String(localized: "반려")
        case "duplicate": return String(localized: "기존 토픽으로 연결됨")
        case "withdrawn": return String(localized: "철회됨")
        default: return String(localized: "상태 확인 중")
        }
    }
}

struct TopicProposalDraft: Encodable {
    var id = UUID()
    var title = ""
    var subtitle = ""
    var category = "society"
    var kind = "discussion"
    var sourceURL = ""
    var low = String(localized: "반대")
    var high = String(localized: "찬성")
    var revision: Int?
    enum CodingKeys: String, CodingKey {
        case id = "p_id", title = "p_title", subtitle = "p_subtitle", category = "p_category"
        case kind = "p_kind", sourceURL = "p_source_url", low = "p_low", high = "p_high", revision = "p_revision"
    }
    var validationMessage: String? {
        if !(5...80).contains(title.trimmingCharacters(in: .whitespacesAndNewlines).count) { return String(localized: "질문은 5~80자로 입력해 주세요.") }
        if !(10...200).contains(subtitle.trimmingCharacters(in: .whitespacesAndNewlines).count) { return String(localized: "배경 설명은 10~200자로 입력해 주세요.") }
        if low.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || high.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || low.count > 20 || high.count > 20 || low == high { return String(localized: "서로 다른 점수 기준을 각각 20자 이내로 입력해 주세요.") }
        if kind == "news" && sourceURL.isEmpty { return String(localized: "뉴스·사건에는 출처가 필요해요.") }
        if !sourceURL.isEmpty && (URL(string: sourceURL)?.scheme != "https" || URL(string: sourceURL)?.host == nil || sourceURL.count > 2000) { return String(localized: "출처는 https://로 시작하는 웹 주소를 입력해 주세요.") }
        return nil
    }
    init() {}
    init(proposal: TopicProposal) {
        id = proposal.id; title = proposal.title; subtitle = proposal.subtitle
        category = proposal.category; kind = proposal.kind; sourceURL = proposal.sourceURL ?? ""
        low = proposal.low; high = proposal.high; revision = proposal.revision
    }
}

struct TopicProposalNotification: Decodable, Identifiable {
    let id: UUID
    let title: String
    let status: String
    let reason: String?
    let topicID: UUID?
    let readAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, title, status, reason
        case topicID = "topic_id", readAt = "read_at"
    }
}

extension RemoteWorldService {
    func myProposals() async throws -> [TopicProposal] {
        try await client.send(.select("topic_submissions", order: "updated_at.desc", limit: 200), as: [TopicProposal].self)
    }
    func submitProposal(_ draft: TopicProposalDraft) async throws {
        if let message = draft.validationMessage { throw APIError.rejected(message) }
        try await client.send(SupabaseRequest(method: .post, path: "rpc/submit_topic_proposal", body: try SupabaseHTTPClient.encoder.encode(draft)))
    }
    func withdrawProposal(_ id: UUID) async throws {
        try await client.send(SupabaseRequest(method: .post, path: "rpc/withdraw_topic_proposal", body: try JSONEncoder().encode(["p_id": id.uuidString])))
    }
    func proposalNotifications() async throws -> [TopicProposalNotification] {
        try await client.send(.select("topic_submission_notifications", order: "created_at.desc", limit: 100), as: [TopicProposalNotification].self)
    }
    func markProposalNotificationRead(_ id: UUID) async throws {
        try await client.send(try .update("topic_submission_notifications", values: ["read_at": ISO8601DateFormatter().string(from: Date())], filters: ["id": SupabaseRequest.eq(id.uuidString)]))
    }
    func topic(id: UUID) async throws -> WorldTopic? {
        let rows = try await client.send(.select("topics_feed", filters: ["id": SupabaseRequest.eq(id.uuidString)], limit: 1), as: [TopicRow].self)
        return rows.first?.toDomain()
    }
    func searchTopics(_ query: String) async throws -> [WorldTopic] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return [] }
        // Escape LIKE wildcard input; query values are URL encoded by the HTTP client.
        let escaped = clean.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "%", with: "\\%").replacingOccurrences(of: "_", with: "\\_").replacingOccurrences(of: "*", with: "")
        let rows = try await client.send(.select("topics_feed", filters: ["title": "ilike.%\(escaped)%"], order: "created_at.desc,id.desc", limit: 20), as: [TopicRow].self)
        return rows.compactMap { $0.toDomain() }
    }
}
