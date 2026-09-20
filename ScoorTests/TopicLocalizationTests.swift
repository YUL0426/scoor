import XCTest
@testable import Scoor

@MainActor
final class TopicLocalizationTests: XCTestCase {
    private func row() throws -> TopicRow {
        let data = Data(#"{"id":"16a61c4f-b665-45b6-afa4-bc7791922adc","category":"students","title":"시험 기간 멘탈","subtitle":"공부하는 사람들의 실시간 감정","created_at":"2026-09-20T00:00:00Z","last_activity_at":"2026-09-20T00:00:00Z","posts_count":4,"global_score":73,"score_delta":0,"score_low_label":"부정적","score_high_label":"긍정적","translations":{"en":{"title":"Exam-season mindset","subtitle":"How people studying are feeling right now","score_low_label":"Negative","score_high_label":"Positive"},"ja":{"title":"試験期間中のメンタル","subtitle":"勉強している人たちの今の気持ち","score_low_label":"ネガティブ","score_high_label":"ポジティブ"}}}"#.utf8)
        return try SupabaseHTTPClient.decoder.decode(TopicRow.self, from: data)
    }

    func testEditorialCopyUsesAppLanguageWithoutChangingIdentityOrStats() throws {
        let source = try row()
        let english = try XCTUnwrap(source.toDomain(language: "en-US"))
        XCTAssertEqual(english.title, "Exam-season mindset")
        XCTAssertEqual(english.subtitle, "How people studying are feeling right now")
        XCTAssertEqual(english.lowLabel, "Negative")
        XCTAssertEqual(english.highLabel, "Positive")
        XCTAssertEqual(english.id, source.id)
        XCTAssertEqual(english.postsCount, 4)
        XCTAssertEqual(english.globalScore, 73)
        XCTAssertEqual(source.toDomain(language: "ja-JP")?.title, "試験期間中のメンタル")
        XCTAssertEqual(source.toDomain(language: "ko-KR")?.title, source.title)
        XCTAssertEqual(source.toDomain(language: "ko")?.subtitle, source.subtitle)
    }

    func testMissingTranslationUsesEnglishThenLegacyOriginal() throws {
        var source = try row()
        XCTAssertEqual(source.toDomain(language: "fr-CA")?.title, "Exam-season mindset")
        source.translations = nil
        XCTAssertEqual(source.toDomain(language: "en")?.title, source.title)
        XCTAssertEqual(source.toDomain(language: "en")?.subtitle, source.subtitle)
    }

    func testLocaleVariantsResolveAllSupportedLanguages() {
        for (input, key) in [("pt_BR", "pt-BR"), ("pt-PT", "pt-BR"), ("zh-Hans-CN", "zh-Hans"),
                             ("de-DE", "de"), ("es-MX", "es"), ("fr-CA", "fr"), ("ja-JP", "ja"),
                             ("ko-KR", "ko"), ("en-GB", "en"), ("ar", "en")] {
            XCTAssertEqual(TopicTranslation.languageKey(input), key)
        }
    }

    func testFeedTopicTitleTranslatesButUserCommentStaysVerbatim() throws {
        let data = Data(#"{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","value":80,"comment":"사용자가 쓴 원문","is_anonymous":true,"country_code":"KR","created_at":"2026-09-20T00:00:00Z","topics":{"id":"16a61c4f-b665-45b6-afa4-bc7791922adc","title":"시험 기간 멘탈","category":"students","translations":{"en":{"title":"Exam-season mindset","subtitle":"Studying","score_low_label":"Negative","score_high_label":"Positive"}}}}"#.utf8)
        let feed = try SupabaseHTTPClient.decoder.decode(WorldScoreFeedRow.self, from: data)
        XCTAssertEqual(feed.topic.title(for: "en"), "Exam-season mindset")
        XCTAssertEqual(feed.topic.title(for: "ko"), "시험 기간 멘탈")
        XCTAssertEqual(feed.reaction.comment, "사용자가 쓴 원문")
    }
}
