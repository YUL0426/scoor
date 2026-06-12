//
//  FeedbackEngineTests.swift
//  ScoorTests
//
//  제출 후 피드백 카피 생성 로직 — 엣지 케이스(0점/100점) 및 연속 기록 갱신.
//

import XCTest
@testable import Scoor

final class FeedbackEngineTests: XCTestCase {

    private let cal = Calendar.current
    private let userId = UUID()

    /// `daysAgo`일 전 날짜의 점수.
    private func score(_ value: Int, daysAgo: Int) -> Score {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Score(userId: userId, value: value, date: date)
    }

    // MARK: - First entry

    func testFirstEntryWelcome() {
        // 오늘 기록 하나뿐 → 환영 메시지.
        let result = FeedbackEngine.generateFeedback(currentScore: 70, history: [score(70, daysAgo: 0)])
        XCTAssertTrue(result.message.contains("Welcome"))
        XCTAssertEqual(result.type, .positive)
    }

    // MARK: - Edge values

    func testPerfectHundredGetsItsOwnMoment() {
        let history = [score(100, daysAgo: 0), score(50, daysAgo: 30)]
        let result = FeedbackEngine.generateFeedback(currentScore: 100, history: history)
        XCTAssertTrue(result.message.contains("100"))
        XCTAssertEqual(result.type, .positive)
    }

    func testZeroDayIsEncouraging() {
        let history = [score(0, daysAgo: 0), score(50, daysAgo: 30)]
        let result = FeedbackEngine.generateFeedback(currentScore: 0, history: history)
        XCTAssertEqual(result.type, .encouragement)
        XCTAssertFalse(result.message.isEmpty)
    }

    // MARK: - Consecutive-logging streak milestone

    func testStreakMilestoneCelebrated() {
        // 오늘 포함 연속 3일 기록 → 마일스톤 콜아웃.
        let history = [score(60, daysAgo: 0), score(60, daysAgo: 1), score(60, daysAgo: 2)]
        let result = FeedbackEngine.generateFeedback(currentScore: 60, history: history)
        XCTAssertTrue(result.message.contains("3 days in a row"), "Got: \(result.message)")
        XCTAssertEqual(result.type, .positive)
    }

    func testNonMilestoneStreakDoesNotTriggerCallout() {
        // 연속 2일은 마일스톤이 아니므로 streak 콜아웃이 나오면 안 된다.
        let history = [score(50, daysAgo: 0), score(50, daysAgo: 45)]
        let result = FeedbackEngine.generateFeedback(currentScore: 50, history: history)
        XCTAssertFalse(result.message.contains("in a row"))
    }

    // MARK: - Fallback

    func testFallbackForOrdinaryScore() {
        // 비교 대상이 없는 평범한 점수 → 기본 기록 확인 메시지.
        let history = [score(50, daysAgo: 0), score(50, daysAgo: 45)]
        let result = FeedbackEngine.generateFeedback(currentScore: 50, history: history)
        XCTAssertEqual(result.type, .neutral)
    }
}
