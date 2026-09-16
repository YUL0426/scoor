import XCTest
@testable import Scoor

@MainActor
final class PersonalStatsSnapshotTests: XCTestCase {
    func testMissingDaysZeroAndPeriodBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6))!
        var entries: [Date: ScoreEntry] = [:]
        for (offset, score) in [(0, 0), (-6, 100), (-7, 40), (-13, 40), (-14, 99), (1, 99)] {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            entries[date] = ScoreEntry(calendarDay: date, score: score, reason: nil)
        }
        let snapshot = PersonalStatsSnapshot(entriesByDay: entries, days: 7, now: now, calendar: calendar)
        XCTAssertEqual(snapshot.entries.count, 2)
        XCTAssertEqual(snapshot.average, 50)
        XCTAssertEqual(snapshot.previousEntries.count, 2)
        XCTAssertEqual(snapshot.delta, 10)
        XCTAssertEqual(snapshot.best?.score, 100)
    }

    func testDailyBucketsIncludeAllSevenDaysWithoutInventingScores() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 8))!
        let entries = [now: ScoreEntry(calendarDay: now, score: 0, reason: nil)]
        let buckets = PersonalStatsPeriod.daily.buckets(entries: entries, now: now, calendar: calendar)
        XCTAssertEqual(buckets.map(\.label), ["9/2", "9/3", "9/4", "9/5", "9/6", "9/7", "9/8"])
        XCTAssertEqual(buckets.filter { $0.average == nil }.count, 6)
        XCTAssertEqual(buckets.last?.average, 0)
    }

    func testWeeklyAndMonthlyBucketsUseCalendarBoundariesAndRecordedDayAverages() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 6))!
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: now)! }
        let entries = [day(-1): ScoreEntry(calendarDay: day(-1), score: 0, reason: nil),
                       now: ScoreEntry(calendarDay: now, score: 100, reason: nil),
                       day(1): ScoreEntry(calendarDay: day(1), score: 100, reason: nil)]
        let weeks = PersonalStatsPeriod.weekly.buckets(entries: entries, now: now, calendar: calendar)
        XCTAssertEqual(weeks.count, 4)
        XCTAssertEqual(weeks.last?.label, "1/5\n–1/11")
        XCTAssertEqual(weeks.last?.average, 50)
        let months = PersonalStatsPeriod.monthly.buckets(entries: entries, now: now, calendar: calendar)
        XCTAssertEqual(months.map(\.label), ["8월", "9월", "10월", "11월", "12월", "1월"])
        XCTAssertEqual(months.last?.average, 50)
    }

    func testEmptyAndNoComparison() {
        let empty = PersonalStatsSnapshot(entriesByDay: [:], days: 30)
        XCTAssertNil(empty.average)
        XCTAssertNil(empty.delta)
        XCTAssertNil(empty.best)
        let today = Calendar.current.startOfDay(for: Date())
        let snapshot = PersonalStatsSnapshot(entriesByDay: [today: ScoreEntry(calendarDay: today, score: 0, reason: nil)], days: 90)
        XCTAssertEqual(snapshot.average, 0)
        XCTAssertNil(snapshot.delta)
    }
}
