//
//  AccountMigrationTests.swift
//  ScoorTests
//
//  Coverage for adopting pre-login data on sign-in (spec-13 §7).
//
//  The failure this guards against is the worst kind: nothing crashes, nothing
//  errors, the calendar simply comes up empty after a guest signs in because the
//  rows are keyed to an id no screen queries any more. So the assertions here are
//  written from the user's side — "the history is visible under the account" —
//  rather than around the mechanics.
//

import XCTest
@testable import Scoor

@MainActor
final class AccountMigrationTests: XCTestCase {

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func score(_ value: Int,
                       user: UUID,
                       daysAgo: Int = 0,
                       createdAt: Date = Date()) -> Score {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return Score(userId: user, value: value, reason: nil, date: day, createdAt: createdAt)
    }

    // MARK: - Re-key

    func testGuestHistoryBecomesVisibleUnderTheAccount() async throws {
        let guestId = UUID()
        let accountId = UUID()
        let store = MockScoreService()
        try await store.saveScore(score(70, user: guestId, daysAgo: 1))
        try await store.saveScore(score(80, user: guestId, daysAgo: 2))

        // Before: signing in would show an empty calendar.
        let beforeAdoption = await store.getScoreHistory(userId: accountId, limit: 365)
        XCTAssertTrue(beforeAdoption.isEmpty)

        let moved = try await store.reassignScores(from: guestId, to: accountId)

        let underAccount = await store.getScoreHistory(userId: accountId, limit: 365)
        let underGuest = await store.getScoreHistory(userId: guestId, limit: 365)
        XCTAssertEqual(moved.count, 2)
        XCTAssertEqual(underAccount.count, 2)
        XCTAssertTrue(underGuest.isEmpty)
    }

    func testReassignIsANoOpWhenTheIdAlreadyMatches() async throws {
        let id = UUID()
        let store = MockScoreService()
        try await store.saveScore(score(60, user: id))

        let moved = try await store.reassignScores(from: id, to: id)

        let history = await store.getScoreHistory(userId: id, limit: 365)
        XCTAssertTrue(moved.isEmpty)
        XCTAssertEqual(history.count, 1)
    }

    /// Second device: the account already recorded today, more recently than the
    /// guest row being adopted. Adopting must not downgrade that day.
    func testNewerRecordOnTheAccountSurvivesAdoption() async throws {
        let guestId = UUID()
        let accountId = UUID()
        let store = MockScoreService()
        let earlier = Date().addingTimeInterval(-3600)

        try await store.saveScore(score(30, user: guestId, createdAt: earlier))
        try await store.saveScore(score(90, user: accountId, createdAt: Date()))

        try await store.reassignScores(from: guestId, to: accountId)

        let history = await store.getScoreHistory(userId: accountId, limit: 365)
        XCTAssertEqual(history.count, 1, "one score per calendar day must still hold")
        XCTAssertEqual(history.first?.value, 90, "the newer write wins")
    }

    func testOlderRecordOnTheAccountIsReplacedByTheNewerGuestWrite() async throws {
        let guestId = UUID()
        let accountId = UUID()
        let store = MockScoreService()

        try await store.saveScore(score(30, user: accountId, createdAt: Date().addingTimeInterval(-3600)))
        try await store.saveScore(score(90, user: guestId, createdAt: Date()))

        try await store.reassignScores(from: guestId, to: accountId)

        let history = await store.getScoreHistory(userId: accountId, limit: 365)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.value, 90)
    }

    // MARK: - Upload timestamps

    /// The backfill must not claim old rows were written now. If it did, a month of
    /// history would look newer than a score the user edited on another device an
    /// hour ago, and the server's last-write-wins would keep the wrong one.
    func testBackfillPreservesTheOriginalWriteTime() {
        let writtenAt = Date().addingTimeInterval(-86_400 * 30)
        let old = score(55, user: UUID(), daysAgo: 30, createdAt: writtenAt)

        let backfill = ScoreSyncOperation.upsert(old, clientUpdatedAt: old.createdAt)
        let liveEdit = ScoreSyncOperation.upsert(old)

        XCTAssertEqual(backfill.clientUpdatedAt, writtenAt)
        XCTAssertGreaterThan(liveEdit.clientUpdatedAt, writtenAt,
                             "a live edit should still stamp now")
    }

    // MARK: - Guestbook

    func testGuestbookEntriesFollowTheAccount() async throws {
        let guestId = UUID()
        let accountId = UUID()
        let friendId = UUID()
        let store = MockGuestbookService()

        try await store.postMessage(authorId: friendId, recipientId: guestId,
                                    content: "환영해!", isPrivate: false)
        try await store.postMessage(authorId: guestId, recipientId: guestId,
                                    content: "내 메모", isPrivate: true)

        try await store.reassignMessages(from: guestId, to: accountId)

        let received = await store.getMessages(recipientId: accountId, includePrivate: true)
        let leftBehind = await store.getMessages(recipientId: guestId, includePrivate: true)
        XCTAssertEqual(received.count, 2)
        XCTAssertTrue(leftBehind.isEmpty)
        // The entry the user wrote on their own page keeps them as the author.
        XCTAssertTrue(received.contains { $0.authorId == accountId })
        // Someone else's entry keeps its original author.
        XCTAssertTrue(received.contains { $0.authorId == friendId })
    }

    // MARK: - Migrator orchestration

    func testMigratorMovesHistoryAndRunsOnlyOnce() async throws {
        let guestId = UUID()
        let accountId = UUID()
        let defaults = makeDefaults()
        let scores = MockScoreService()
        try await scores.saveScore(score(65, user: guestId, daysAgo: 1))

        let migrator = AccountMigrator(
            scoreService: scores,
            guestbookService: MockGuestbookService(),
            userService: MockUserService(seedCurrentUser: User(username: "scoor_user", email: "a@b.c")),
            defaults: defaults
        )

        await migrator.migrateIfNeeded(from: guestId, to: accountId)
        let afterFirstRun = await scores.getScoreHistory(userId: accountId, limit: 365)
        XCTAssertEqual(afterFirstRun.count, 1)

        // A day recorded after migration under a *new* guest id must not be pulled
        // in by a second run — the migration is done and should stay done.
        let strayId = UUID()
        try await scores.saveScore(score(10, user: strayId, daysAgo: 5))
        await migrator.migrateIfNeeded(from: strayId, to: accountId)

        let afterSecondRun = await scores.getScoreHistory(userId: accountId, limit: 365)
        let strayHistory = await scores.getScoreHistory(userId: strayId, limit: 365)
        XCTAssertEqual(afterSecondRun.count, 1, "migration should be idempotent per account")
        XCTAssertEqual(strayHistory.count, 1)
    }

    func testMigratorRetriesWhenNothingHasBeenAdoptedYet() async throws {
        let accountId = UUID()
        let defaults = makeDefaults()
        let scores = MockScoreService()

        let migrator = AccountMigrator(
            scoreService: scores,
            guestbookService: MockGuestbookService(),
            userService: MockUserService(seedCurrentUser: User(username: "scoor_user", email: "a@b.c")),
            defaults: defaults
        )

        // Signing in with nothing recorded locally still marks the account adopted,
        // so a later guest id cannot silently graft data onto the account.
        await migrator.migrateIfNeeded(from: nil, to: accountId)
        let history = await scores.getScoreHistory(userId: accountId, limit: 365)
        XCTAssertTrue(history.isEmpty)
    }

    // MARK: - Username sanitising

    func testUsernameSanitisingMatchesTheServerConstraint() {
        // Placeholder default is not a real chosen name.
        XCTAssertNil(AccountMigrator.sanitizedUsername("scoor_user"))
        // check (char_length between 2 and 20)
        XCTAssertNil(AccountMigrator.sanitizedUsername("a"))
        XCTAssertNil(AccountMigrator.sanitizedUsername(String(repeating: "x", count: 21)))
        XCTAssertNil(AccountMigrator.sanitizedUsername("   "))
        XCTAssertEqual(AccountMigrator.sanitizedUsername("  유리  "), "유리")
        XCTAssertEqual(AccountMigrator.sanitizedUsername("scoorer"), "scoorer")
    }
}
