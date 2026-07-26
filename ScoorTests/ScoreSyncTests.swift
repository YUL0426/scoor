//
//  ScoreSyncTests.swift
//  ScoorTests
//
//  Coverage for the local-first sync layer's pure building blocks (spec-13 §5).
//  These run with no backend: the outbox, the day-key derivation that decides
//  which calendar cell a score lands in, and the provisioning check that decides
//  whether the app talks to a server at all.
//

import XCTest
@testable import Scoor

final class ScoreSyncQueueTests: XCTestCase {

    /// Each test gets its own suite so the queue's UserDefaults persistence is real
    /// but isolated — the collapsing/persistence behavior is the thing under test.
    private func makeDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
        UserDefaults(suiteName: name)!
    }

    private func score(_ value: Int, day: Date, user: UUID) -> Score {
        Score(userId: user, value: value, reason: nil, date: day)
    }

    func testEnqueueCollapsesRepeatedEditsOfTheSameDay() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        let user = UUID()
        let today = Date()

        await queue.enqueue(.upsert(score(50, day: today, user: user)))
        await queue.enqueue(.upsert(score(70, day: today, user: user)))
        await queue.enqueue(.upsert(score(90, day: today, user: user)))

        // Editing today's score three times offline must upload once, with the
        // last value — not three times.
        let ops = await queue.operations
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.value, 90)
    }

    func testDifferentDaysAreKeptSeparately() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        let user = UUID()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        await queue.enqueue(.upsert(score(50, day: today, user: user)))
        await queue.enqueue(.upsert(score(60, day: yesterday, user: user)))

        let count = await queue.count
        XCTAssertEqual(count, 2)
    }

    func testDifferentUsersDoNotCollapse() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        let today = Date()

        await queue.enqueue(.upsert(score(50, day: today, user: UUID())))
        await queue.enqueue(.upsert(score(60, day: today, user: UUID())))

        let count = await queue.count
        XCTAssertEqual(count, 2)
    }

    func testDeleteSupersedesAPendingUpsertForTheSameDay() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        let user = UUID()
        let today = Date()
        let s = score(50, day: today, user: user)

        await queue.enqueue(.upsert(s))
        await queue.enqueue(.delete(s))

        // Recording then deleting a day while offline must upload a tombstone,
        // not resurrect the score.
        let ops = await queue.operations
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.kind, .delete)
    }

    func testQueueSurvivesRelaunch() async {
        let name = UUID().uuidString
        let user = UUID()
        let queue = ScoreSyncQueue(defaults: makeDefaults(name))
        await queue.enqueue(.upsert(score(42, day: Date(), user: user)))

        // A new instance over the same store stands in for a relaunch: a score
        // recorded offline must still upload after the app is killed.
        let reloaded = ScoreSyncQueue(defaults: makeDefaults(name))
        let ops = await reloaded.operations
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(ops.first?.value, 42)
    }

    func testPoisonOperationIsDroppedAfterRepeatedFailures() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        await queue.enqueue(.upsert(score(50, day: Date(), user: UUID())))
        guard let id = await queue.operations.first?.id else {
            return XCTFail("expected a queued operation")
        }

        // An operation the server will never accept must not retry forever and
        // block everything behind it.
        for _ in 0..<8 { await queue.recordFailure(id) }

        let count = await queue.count
        XCTAssertEqual(count, 0)
    }

    func testRemoveAllClearsQueueAndWatermark() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        await queue.enqueue(.upsert(score(50, day: Date(), user: UUID())))
        await queue.markSynced(at: Date())

        // Account deletion (P0-4) must not leave uploads that would resurrect
        // data the user just erased.
        await queue.removeAll()

        let count = await queue.count
        let watermark = await queue.lastSyncedAt
        XCTAssertEqual(count, 0)
        XCTAssertNil(watermark)
    }
}

final class ScoreSyncFormatTests: XCTestCase {

    /// The day key must follow the user's local calendar, not UTC. A 09:00 KST
    /// entry is "today" even though it is still yesterday in UTC — getting this
    /// wrong shifts entries by a day on the calendar screen.
    func testDayKeyUsesLocalCalendarNotUTC() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        // 2026-07-17 09:00 KST == 2026-07-17 00:00 UTC.
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 17
        components.hour = 9; components.minute = 0
        components.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(ScoreSyncFormat.day(from: date, calendar: calendar), "2026-07-17")
    }

    /// Just after local midnight is the riskiest case: in KST this is still the
    /// previous day in UTC, so a UTC-based key would file it under yesterday.
    func testDayKeyJustAfterLocalMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 17
        components.hour = 0; components.minute = 30
        components.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let date = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(ScoreSyncFormat.day(from: date, calendar: calendar), "2026-07-17")
    }

    func testDayKeyRoundTrips() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let day = "2026-07-17"
        let date = ScoreSyncFormat.date(fromDay: day, calendar: calendar)
        XCTAssertNotNil(date)
        XCTAssertEqual(ScoreSyncFormat.day(from: date!, calendar: calendar), day)
    }

    /// Guards against a locale with a non-Gregorian calendar (e.g. Japanese era
    /// on a device set to 和暦) producing "R08-07-17" instead of an ISO date.
    func testDayKeyIsISOEvenUnderNonGregorianLocale() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.locale = Locale(identifier: "ja_JP@calendar=japanese")

        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 17
        components.hour = 12
        components.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let date = Calendar(identifier: .gregorian).date(from: components)!

        XCTAssertEqual(ScoreSyncFormat.day(from: date, calendar: calendar), "2026-07-17")
    }
}

final class SupabaseConfigTests: XCTestCase {

    /// Stands in for the Info.plist lookup.
    private func lookup(host: String?, key: String?) -> (String) -> String? {
        { name in
            switch name {
            case "SupabaseHost":    return host
            case "SupabaseAnonKey": return key
            default:                return nil
            }
        }
    }

    func testResolvesProvisionedConfig() {
        let config = SupabaseConfig.resolve(value: lookup(host: "abc.supabase.co", key: "anon-key"))
        XCTAssertEqual(config?.baseURL.absoluteString, "https://abc.supabase.co")
        XCTAssertEqual(config?.restURL.absoluteString, "https://abc.supabase.co/rest/v1")
        XCTAssertEqual(config?.anonKey, "anon-key")
    }

    /// The whole local-only fallback rests on this: an unset xcconfig var leaves
    /// the literal "$(SUPABASE_HOST)" in Info.plist, which must read as absent
    /// rather than as a hostname.
    func testUnexpandedPlaceholderCountsAsNotProvisioned() {
        let config = SupabaseConfig.resolve(
            value: lookup(host: "$(SUPABASE_HOST)", key: "$(SUPABASE_ANON_KEY)")
        )
        XCTAssertNil(config)
    }

    func testEmptyValuesCountAsNotProvisioned() {
        XCTAssertNil(SupabaseConfig.resolve(value: lookup(host: "  ", key: "anon-key")))
        XCTAssertNil(SupabaseConfig.resolve(value: lookup(host: "abc.supabase.co", key: "")))
        XCTAssertNil(SupabaseConfig.resolve(value: lookup(host: nil, key: nil)))
    }

    /// Pasting the full Project URL despite the scheme-less instruction is the
    /// obvious setup mistake; it should still work rather than build "https://https://…".
    func testTolerantOfAPastedSchemeInHost() {
        let config = SupabaseConfig.resolve(value: lookup(host: "https://abc.supabase.co", key: "k"))
        XCTAssertEqual(config?.baseURL.absoluteString, "https://abc.supabase.co")
    }
}

final class APIErrorTests: XCTestCase {

    /// The retry policy is what keeps a poison write from blocking the outbox and
    /// an offline user from losing a day's record.
    func testRetryClassification() {
        XCTAssertTrue(APIError.offline.isRetryable)
        XCTAssertTrue(APIError.rateLimited.isRetryable)
        XCTAssertTrue(APIError.server(status: 503, message: nil).isRetryable)

        XCTAssertFalse(APIError.rejected("RLS").isRetryable)
        XCTAssertFalse(APIError.unauthorized.isRetryable)
        XCTAssertFalse(APIError.server(status: 400, message: nil).isRetryable)
        XCTAssertFalse(APIError.updateRequired.isRetryable)
    }
}
