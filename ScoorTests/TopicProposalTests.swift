import XCTest
@testable import Scoor

final class TopicProposalTests: XCTestCase {
    @MainActor
    func testNewsRequiresHTTPSAndDistinctScoreAnchors() {
        var draft = TopicProposalDraft()
        draft.title = "주 4일 재택근무 도입에 찬성하나요?"
        draft.subtitle = "출퇴근과 업무 집중에 미치는 영향을 논의해요."
        XCTAssertNil(draft.validationMessage)
        draft.kind = "news"
        XCTAssertNotNil(draft.validationMessage)
        draft.sourceURL = "javascript:alert(1)"
        XCTAssertNotNil(draft.validationMessage)
        draft.sourceURL = "https://example.com/news"
        XCTAssertNil(draft.validationMessage)
        draft.high = draft.low
        XCTAssertNotNil(draft.validationMessage)
    }

    @MainActor
    func testServerTopicPreservesQuestionAndScoreMeaning() throws {
        let json = """
        {"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","category":"work","title":"주 4일 재택근무?",
        "subtitle":"서버에 저장된 배경 설명","cover_emoji":null,"status":"closed","origin":"community",
        "proposed_by":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","proposer_name":"제안자","source_url":"https://example.com/news",
        "score_low_label":"반대","score_high_label":"찬성","created_at":"2026-09-08T00:00:00Z",
        "last_activity_at":"2026-09-08T00:00:00Z","posts_count":0,"global_score":0,"score_delta":0}
        """
        let row = try SupabaseHTTPClient.decoder.decode(TopicRow.self, from: Data(json.utf8))
        let topic = try XCTUnwrap(row.toDomain())
        XCTAssertEqual(topic.subtitle, "서버에 저장된 배경 설명")
        XCTAssertEqual(topic.origin, "community")
        XCTAssertEqual(topic.status, "closed")
        XCTAssertEqual(topic.lowLabel, "반대")
        XCTAssertEqual(topic.highLabel, "찬성")
        XCTAssertEqual(topic.proposerName, "제안자")
    }

    @MainActor
    func testDraftRetryKeepsSameIDAndReviewVersion() throws {
        let json = """
        {"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","title":"주 4일 근무 도입?","subtitle":"주 4일 근무의 장단점을 논의해요.",
        "category":"work","kind":"discussion","source_url":null,"score_low_label":"반대","score_high_label":"찬성",
        "status":"changes_requested","revision":2,"review_reason":"질문을 구체화해 주세요.","topic_id":null}
        """
        let proposal = try JSONDecoder().decode(TopicProposal.self, from: Data(json.utf8))
        let draft = TopicProposalDraft(proposal: proposal)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as! [String: Any]
        XCTAssertEqual((encoded["p_id"] as? String)?.lowercased(), proposal.id.uuidString.lowercased())
        XCTAssertEqual(encoded["p_revision"] as? Int, 2)
        XCTAssertTrue(proposal.editable)
    }
}
