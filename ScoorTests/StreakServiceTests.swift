//
//  StreakServiceTests.swift
//  ScoorTests
//
//  StreakService(연속 기록 단일 진실 공급원) 유닛 테스트.
//

import XCTest
@testable import Scoor

final class StreakServiceTests: XCTestCase {

    // MARK: - Helpers

    /// UTC 고정 그레고리력 — 타임존 흔들림 없이 결정론적으로 테스트.
    private func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// `daysAgo`만큼 과거의 날짜(해당 달력의 하루 시작).
    private func day(_ daysAgo: Int, from anchor: Date, _ cal: Calendar) -> Date {
        cal.startOfDay(for: cal.date(byAdding: .day, value: -daysAgo, to: anchor)!)
    }

    /// 주어진 "며칠 전" 목록으로 entriesByDay 사전을 만든다.
    private func entries(daysAgo: [Int], anchor: Date, cal: Calendar, score: Int = 50) -> [Date: ScoreEntry] {
        var result: [Date: ScoreEntry] = [:]
        for d in daysAgo {
            let key = day(d, from: anchor, cal)
            result[key] = ScoreEntry(calendarDay: key, score: score, reason: nil)
        }
        return result
    }

    private func fixedToday(_ cal: Calendar) -> Date {
        // 2026-06-03 정오 UTC — 정규화 전 시간 성분이 있어도 startOfDay로 처리되는지 함께 검증.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 3; comps.hour = 12
        return cal.date(from: comps)!
    }

    // MARK: - Consecutive days

    func testConsecutiveDaysIncludingToday() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // 오늘, 어제, 그제 연속 3일.
        let e = entries(daysAgo: [0, 1, 2], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 3)
    }

    // MARK: - Missed day breaks the streak

    func testMissedDayBreaksStreak() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // 오늘, 어제 기록 / 그제(2일 전) 빠짐 / 3일 전 기록.
        let e = entries(daysAgo: [0, 1, 3], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 2)
    }

    // MARK: - Multiple entries same day == 1

    func testMultipleEntriesSameDayCountAsOne() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // ScoreCalendarIndex는 하루당 한 칸(last-write-wins)이므로 같은 날 여러 점수도 1일.
        let scores = [
            Score(userId: UUID(), value: 30, date: today),
            Score(userId: UUID(), value: 70, date: cal.date(byAdding: .hour, value: 3, to: today)!)
        ]
        let e = ScoreCalendarIndex.entriesByDay(from: scores, calendar: cal)
        XCTAssertEqual(e.count, 1)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 1)
    }

    // MARK: - Streak stays alive when today not yet scored

    func testStreakAliveWhenTodayMissingButYesterdayPresent() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // 오늘은 아직 기록 전, 어제·그제 연속.
        let e = entries(daysAgo: [1, 2], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 2,
                       "오늘이 끝나기 전까지 어제 기록만으로도 streak는 유지되어야 한다")
    }

    func testStreakZeroWhenNeitherTodayNorYesterday() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // 가장 최근 기록이 2일 전 — 어제가 비었으므로 streak 끊김.
        let e = entries(daysAgo: [2, 3], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 0)
    }

    // MARK: - Empty

    func testEmptyEntriesReturnsZero() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: [:], today: today, calendar: cal), 0)
        XCTAssertEqual(StreakService.longestStreak(entriesByDay: [:], calendar: cal), 0)
    }

    // MARK: - Longest streak

    func testLongestStreak() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        // 연속 구간: [0,1,2] (3일), 공백 3일전, [4,5] (2일), 공백, [8,9,10,11] (4일).
        let e = entries(daysAgo: [0, 1, 2, 4, 5, 8, 9, 10, 11], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.longestStreak(entriesByDay: e, calendar: cal), 4)
    }

    func testLongestStreakSingleDay() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        let e = entries(daysAgo: [5], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.longestStreak(entriesByDay: e, calendar: cal), 1)
    }

    // MARK: - Combined result

    func testStreakResultCombinesCurrentAndLongest() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        let e = entries(daysAgo: [0, 1, 4, 5, 6, 7], anchor: today, cal: cal)
        let result = StreakService.streak(entriesByDay: e, today: today, calendar: cal)
        XCTAssertEqual(result.current, 2)   // 오늘, 어제
        XCTAssertEqual(result.longest, 4)   // 4..7
    }

    // MARK: - Timezone / DST edge

    func testStreakAcrossDSTBoundary() {
        // 미국 동부: 2025-03-09 02:00에 봄철 DST 시작(하루가 23시간).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!

        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 10; comps.hour = 12
        let today = cal.date(from: comps)!

        // DST 전환을 가로지르는 연속 4일 (3/7, 3/8, 3/9, 3/10).
        let e = entries(daysAgo: [0, 1, 2, 3], anchor: today, cal: cal)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: today, calendar: cal), 4,
                       "DST 경계를 넘어도 달력상 연속일이면 streak가 유지되어야 한다")
    }

    func testStreakIndependentOfTimeComponentInToday() {
        let cal = utcCalendar()
        let base = fixedToday(cal)
        let e = entries(daysAgo: [0, 1], anchor: base, cal: cal)
        // 같은 날의 자정 직후 / 직전 시각 모두 동일 결과여야 한다.
        let earlyToday = cal.startOfDay(for: base)
        let lateToday = cal.date(byAdding: .second, value: -1, to: cal.date(byAdding: .day, value: 1, to: earlyToday)!)!
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: earlyToday, calendar: cal), 2)
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e, today: lateToday, calendar: cal), 2)
    }

    // MARK: - App restart persistence (derivation is deterministic from stored scores)

    func testStreakIsDeterministicAcrossReindexing() {
        let cal = utcCalendar()
        let today = fixedToday(cal)
        let userId = UUID()
        // "재시작" 시뮬레이션: 동일한 점수 집합을 다시 인덱싱해도 같은 streak.
        let scores = (0..<5).map { offset in
            Score(userId: userId, value: 60, date: day(offset, from: today, cal))
        }
        let e1 = ScoreCalendarIndex.entriesByDay(from: scores, calendar: cal)
        let e2 = ScoreCalendarIndex.entriesByDay(from: scores.shuffled(), calendar: cal)
        XCTAssertEqual(
            StreakService.currentStreak(entriesByDay: e1, today: today, calendar: cal),
            StreakService.currentStreak(entriesByDay: e2, today: today, calendar: cal)
        )
        XCTAssertEqual(StreakService.currentStreak(entriesByDay: e1, today: today, calendar: cal), 5)
    }
}
