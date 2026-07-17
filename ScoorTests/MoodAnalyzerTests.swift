//
//  MoodAnalyzerTests.swift
//  ScoorTests
//
//  파생 감정 분석 시임(MoodAnalyzing) 유닛 테스트.
//  - DisabledMoodAnalyzer: 항상 nil (현재 프로덕션 기본값 — 동작 변화 없음).
//  - RuleBasedMoodAnalyzer: 키워드 우선 → 점수밴드 폴백.
//

import XCTest
@testable import Scoor

final class MoodAnalyzerTests: XCTestCase {

    // MARK: - Disabled (production default)

    func testDisabledAnalyzerAlwaysReturnsNil() async {
        let analyzer = DisabledMoodAnalyzer()
        let a = await analyzer.analyze(score: 95, reason: "행복한 하루")
        let b = await analyzer.analyze(score: 0, reason: nil)
        XCTAssertNil(a)
        XCTAssertNil(b, "비활성 분석기는 입력과 무관하게 항상 nil이어야 한다")
    }

    // MARK: - RuleBased: keyword precedence

    func testKeywordSignalTakesPrecedenceOverScoreBand() async {
        let analyzer = RuleBasedMoodAnalyzer()
        // 점수만 보면 happy(75+)지만, 사유 키워드(번아웃)가 우선해야 한다.
        let mood = await analyzer.analyze(score: 90, reason: "번아웃이 와서 힘들다")
        XCTAssertEqual(mood, .burnout)
    }

    func testEnglishKeywordMatch() async {
        let analyzer = RuleBasedMoodAnalyzer()
        let mood = await analyzer.analyze(score: 40, reason: "feeling so lonely today")
        XCTAssertEqual(mood, .lonely)
    }

    // MARK: - RuleBased: score-band fallback

    func testScoreBandFallbackWhenNoKeyword() async {
        let analyzer = RuleBasedMoodAnalyzer()
        let high = await analyzer.analyze(score: 88, reason: nil)
        let mid = await analyzer.analyze(score: 60, reason: "그냥 그런 하루")
        let low = await analyzer.analyze(score: 45, reason: nil)
        let veryLow = await analyzer.analyze(score: 10, reason: nil)
        XCTAssertEqual(high, .happy)
        XCTAssertEqual(mid, .calm)
        XCTAssertEqual(low, .lonely)
        XCTAssertEqual(veryLow, .burnout)
    }

    func testNoSignalReturnsNil() async {
        let analyzer = RuleBasedMoodAnalyzer()
        // 점수 0 + 사유 없음 → 분류할 신호 없음.
        let mood = await analyzer.analyze(score: 0, reason: nil)
        XCTAssertNil(mood)
    }
}
