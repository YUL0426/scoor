import XCTest
@testable import Scoor

@MainActor
final class RepostTests: XCTestCase {
    private let userID = UUID()
    private let postID = UUID()

    private func service(userID: UUID?) -> RemoteFeedService {
        RemoteFeedService(client: SupabaseHTTPClient(
            config: SupabaseConfig(baseURL: URL(string: "https://repost-test.invalid")!, anonKey: "test"),
            tokenProvider: nil, session: ReleaseAuditURLProtocol.session()), currentUserID: { userID })
    }

    func testRepostUsesIdempotentWriteAndScopedDelete() async throws {
        let remote = service(userID: userID)
        ReleaseAuditURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/rest/v1/post_reposts")
            XCTAssertTrue(request.url!.query!.contains("on_conflict=post_id,user_id"))
            XCTAssertTrue(request.value(forHTTPHeaderField: "Prefer")!.contains("merge-duplicates"))
            return (204, Data())
        }
        try await remote.setRepost(postId: postID, reposted: true)
        let post = postID.uuidString.lowercased(), user = userID.uuidString.lowercased()
        ReleaseAuditURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertTrue(query.contains(URLQueryItem(name: "post_id", value: "eq.\(post)")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "user_id", value: "eq.\(user)")))
            return (204, Data())
        }
        try await remote.setRepost(postId: postID, reposted: false)
    }

    func testRepostListFiltersCurrentUserAndPaginatesByRepostDate() async throws {
        ReleaseAuditURLProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            XCTAssertTrue(query.contains(URLQueryItem(name: "reposted_by_me", value: "eq.true")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "order", value: "reposted_at.desc,id.desc")))
            XCTAssertTrue(query.contains(URLQueryItem(name: "offset", value: "8")))
            return (200, Data("[]".utf8))
        }
        let entries = try await service(userID: userID).loadReposts(page: 1, pageSize: 8)
        XCTAssertTrue(entries.isEmpty)
    }

    func testGuestCannotRepost() async {
        do {
            try await service(userID: nil).setRepost(postId: postID, reposted: true)
            XCTFail("Guest write must fail")
        } catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }

    func testSuccessfulRepostAndCancellationUpdateCard() async throws {
        ReleaseAuditURLProtocol.handler = { _ in (204, Data()) }
        let model = FeedViewModel(service: MockSocialService(), remote: service(userID: userID))
        model.entries = [MockFeed.entries[0]]
        let id = model.entries[0].id, count = model.entries[0].reactions.reposts
        model.toggleRepost(entryId: id)
        for _ in 0..<100 where !model.pendingReposts.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(model.entries[0].reactions.repostedByMe)
        XCTAssertEqual(model.entries[0].reactions.reposts, count + 1)
        model.toggleRepost(entryId: id)
        for _ in 0..<100 where !model.pendingReposts.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(model.entries[0].reactions.repostedByMe)
        XCTAssertEqual(model.entries[0].reactions.reposts, count)
    }

    func testCancellingRepostRemovesItFromMyPageWithoutStaleBinding() async throws {
        ReleaseAuditURLProtocol.handler = { _ in (204, Data()) }
        let model = FeedViewModel(service: MockSocialService(), remote: service(userID: userID), repostsOnly: true)
        var entry = MockFeed.entries[0]
        entry.reactions.repostedByMe = true
        model.entries = [entry]
        let binding = try XCTUnwrap(model.binding(for: entry.id))
        model.toggleRepost(entryId: entry.id)
        for _ in 0..<100 where !model.pendingReposts.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(model.entries.isEmpty)
        XCTAssertEqual(binding.wrappedValue.id, entry.id)
        binding.wrappedValue = entry
        XCTAssertTrue(model.entries.isEmpty)
    }

    func testFailedRepostLeavesCardUnchangedAndShowsError() async throws {
        ReleaseAuditURLProtocol.handler = { _ in (403, Data("{}".utf8)) }
        let model = FeedViewModel(service: MockSocialService(), remote: service(userID: userID))
        model.entries = [MockFeed.entries[0]]
        let before = model.entries[0]
        model.toggleRepost(entryId: before.id)
        for _ in 0..<100 where !model.pendingReposts.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(model.pendingReposts.isEmpty)
        XCTAssertEqual(model.entries[0], before)
        XCTAssertNotNil(model.transientError)
    }
}
