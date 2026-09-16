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
import SwiftData
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

    func testOfflineOperationSurvivesRepeatedFailuresAndRelaunch() async {
        let defaults = makeDefaults()
        let queue = ScoreSyncQueue(defaults: defaults)
        await queue.enqueue(.upsert(score(50, day: Date(), user: UUID())))
        guard let id = await queue.operations.first?.id else {
            return XCTFail("expected a queued operation")
        }

        // Repeated offline launches must not discard unsynced data.
        for _ in 0..<20 { await queue.recordFailure(id) }

        let reloaded = ScoreSyncQueue(defaults: defaults)
        let operations = await reloaded.operations
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations.first?.id, id)
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

// Deterministic HTTP regressions; no production writes or real credentials.
final class ReleaseAuditURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
    static func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ReleaseAuditURLProtocol.self]
        return URLSession(configuration: config)
    }
}

@MainActor
final class ReleaseBlockerRegressionTests: XCTestCase {
    private let config = SupabaseConfig(baseURL: URL(string: "https://audit.invalid")!, anonKey: "test-public-key")

    func testProviderExchangeFailureDoesNotCreateLocalSession() async {
        ReleaseAuditURLProtocol.handler = { _ in (401, Data("{}".utf8)) }
        let auth = AuthService(config: config, session: ReleaseAuditURLProtocol.session())
        auth.signOut()
        do {
            _ = try await auth.finish(AuthenticatedIdentity(provider: .apple,
                providerUserID: "audit", identityToken: "invalid"), providerName: "apple")
            XCTFail("Rejected provider tokens must fail sign-in")
        } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
        XCTAssertFalse(auth.isSignedIn)
    }

    private func seedExpiredSession(user: UUID) throws {
        let stored = SupabaseSession(accessToken: "expired", refreshToken: "refresh-old",
            expiresAt: Date(timeIntervalSince1970: 0), userId: user, email: "audit@example.invalid")
        XCTAssertTrue(KeychainStore.set(String(data: try JSONEncoder().encode(stored), encoding: .utf8),
                                        for: "scoor.auth.supabaseSession"))
        let identity = AuthSession(provider: "email", providerUserID: "audit@example.invalid",
            email: "audit@example.invalid", userID: user, signedInAt: Date())
        UserDefaults.standard.set(try JSONEncoder().encode(identity), forKey: "scoor.authSession")
    }

    func testDeletionRefreshesExpiredTokenBeforeSendingRequest() async throws {
        let user = UUID()
        try seedExpiredSession(user: user)
        var sawRefresh = false, sawDelete = false
        ReleaseAuditURLProtocol.handler = { request in
            if request.url!.path == "/auth/v1/token" {
                sawRefresh = true
                return (200, Data("{\"access_token\":\"fresh\",\"refresh_token\":\"refresh-new\",\"expires_in\":3600,\"user\":{\"id\":\"\(user.uuidString)\"}}".utf8))
            }
            if request.url!.path == "/functions/v1/account-delete" {
                sawDelete = true
                XCTAssertTrue(sawRefresh)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh")
            }
            return (200, Data("{}".utf8))
        }
        let auth = AuthService(config: config, session: ReleaseAuditURLProtocol.session())
        defer { auth.signOut() }
        try await auth.deleteAccount()
        XCTAssertTrue(sawDelete)
        XCTAssertFalse(auth.isSignedIn)
    }

    func testTemporaryRefreshFailureKeepsRestorableSession() async throws {
        try seedExpiredSession(user: UUID())
        ReleaseAuditURLProtocol.handler = { _ in (503, Data("{}".utf8)) }
        let auth = AuthService(config: config, session: ReleaseAuditURLProtocol.session())
        let token = await auth.currentAccessToken()
        XCTAssertNil(token)
        XCTAssertTrue(auth.isSignedIn)
        XCTAssertNotNil(KeychainStore.get("scoor.auth.supabaseSession"))
        auth.signOut()
    }

    func testBackendDeletionWithoutTokenFailsInsteadOfReportingSuccess() async {
        let auth = AuthService(config: config, session: ReleaseAuditURLProtocol.session())
        auth.signOut()
        do {
            try await auth.deleteAccount()
            XCTFail("Missing backend session cannot mean deletion succeeded")
        } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }

    func testDeletingOneAccountPreservesOtherAccountsOfflineRecords() async throws {
        let a = UUID(), b = UUID()
        let queue = ScoreSyncQueue(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let local = MockScoreService()
        for user in [a, b] {
            let score = Score(userId: user, value: 71, date: Date())
            try await local.saveScore(score)
            await queue.enqueue(.upsert(score))
        }
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil)
        let remote = RemoteScoreService(local: local, client: client, queue: queue)
        try await remote.deleteLocalScores(userId: a)
        let aRows = await local.getScoreHistory(userId: a, limit: 100)
        let bRows = await local.getScoreHistory(userId: b, limit: 100)
        let pending = await queue.operations
        XCTAssertTrue(aRows.isEmpty)
        XCTAssertEqual(bRows.count, 1)
        XCTAssertEqual(pending.map(\.userId), [b])
    }

    func testSwiftDataAccountDeletionKeepsOtherOwnersScoresAndGuestbook() async throws {
        let container = try ModelContainer(for: ScoreModel.self, GuestbookRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let scores = SwiftDataScoreService(modelContext: container.mainContext)
        let messages = SwiftDataGuestbookService(modelContext: container.mainContext)
        let a = UUID(), b = UUID()
        for user in [a, b] {
            try await scores.saveScore(Score(userId: user, value: 63, date: Date()))
            try await messages.postMessage(authorId: user, recipientId: user, content: "private", isPrivate: true)
        }
        try await scores.deleteLocalScores(userId: a)
        try await messages.deleteMessages(userId: a)
        let remainingScores = await scores.getScoreHistory(userId: b, limit: 100)
        let remainingMessages = await messages.getMessages(recipientId: b, includePrivate: true)
        let removedMessages = await messages.getMessages(recipientId: a, includePrivate: true)
        XCTAssertEqual(remainingScores.count, 1)
        XCTAssertEqual(remainingMessages.count, 1)
        XCTAssertTrue(removedMessages.isEmpty)
    }

    func testCommentOwnerReachesBlockAction() {
        let owner = UUID()
        let row = CommentRow(id: UUID(), postId: UUID(), authorId: owner,
                             text: "comment", isAnonymous: false, createdAt: Date(),
                             editedAt: nil, profiles: .init(username: "user"))
        XCTAssertEqual(row.toDomain(currentUserID: nil).authorId, owner)
    }

    func testAccountSwitchOnlyUploadsCurrentOwnersOperations() async {
        let a = UUID(), b = UUID()
        let queue = ScoreSyncQueue(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await queue.enqueue(.upsert(Score(userId: a, value: 10, date: Date())))
        await queue.enqueue(.upsert(Score(userId: b, value: 20, date: Date())))
        var requests = 0
        ReleaseAuditURLProtocol.handler = { request in
            requests += 1
            return (204, Data())
        }
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil,
                                       session: ReleaseAuditURLProtocol.session())
        let remote = RemoteScoreService(local: MockScoreService(), client: client,
                                        queue: queue, currentUserID: { b })
        await remote.push()
        let remaining = await queue.operations
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(remaining.map(\.userId), [a])
    }

    func testUnauthorizedUploadRemainsQueuedForReauthentication() async {
        let user = UUID()
        let queue = ScoreSyncQueue(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await queue.enqueue(.upsert(Score(userId: user, value: 40, date: Date())))
        ReleaseAuditURLProtocol.handler = { _ in (401, Data("{}".utf8)) }
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil,
                                       session: ReleaseAuditURLProtocol.session())
        let remote = RemoteScoreService(local: MockScoreService(), client: client,
                                        queue: queue, currentUserID: { user })
        await remote.push()
        let count = await queue.count
        XCTAssertEqual(count, 1)
    }

    func testPullIncludesLateOfflineRecordsDespitePreviousAccountWatermark() async throws {
        let user = UUID()
        let queue = ScoreSyncQueue(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        await queue.markSynced(at: Date())
        let row = ScoreRow(userId: user, day: "2026-08-01", value: 73, reason: "offline",
                           mood: nil, clientUpdatedAt: Date(timeIntervalSince1970: 1000), deletedAt: nil)
        let data = try SupabaseHTTPClient.encoder.encode([row])
        ReleaseAuditURLProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertFalse(query.contains { $0.name == "client_updated_at" })
            XCTAssertTrue(query.contains { $0.name == "user_id" && $0.value == "eq." + user.uuidString.lowercased() })
            return (200, data)
        }
        let local = MockScoreService()
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil,
                                       session: ReleaseAuditURLProtocol.session())
        let remote = RemoteScoreService(local: local, client: client, queue: queue, currentUserID: { user })
        await remote.pull(userId: user)
        let records = await local.getScoresForDate(userId: user, date: ScoreSyncFormat.date(fromDay: "2026-08-01")!)
        XCTAssertEqual(records.first?.value, 73)
        XCTAssertEqual(records.first?.reason, "offline")
    }
}
