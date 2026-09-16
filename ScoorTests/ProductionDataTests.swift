import SwiftData
import XCTest
@testable import Scoor

@MainActor
final class ProductionDataTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: ScoreModel.self, LikeRecord.self, CommentRecord.self,
            WorldScoreRecord.self, FollowRecord.self, GuestbookRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testProductionWithoutBackendDoesNotInventUsersOrActivity() async throws {
        let container = try makeContainer()
        let services = AppServices(modelContext: container.mainContext)
        XCTAssertFalse(services.socialService.usesPreviewData)
        for page in 0...2 {
            let feed = await services.socialService.loadFeed(page: page, pageSize: 8)
            let world = await services.socialService.loadWorldPosts(page: page, pageSize: 8)
            XCTAssertTrue(feed.isEmpty)
            XCTAssertTrue(world.isEmpty)
        }
        let topics = await services.socialService.loadTopics()
        let discover = await services.socialService.loadDiscover()
        XCTAssertTrue(topics.isEmpty)
        XCTAssertTrue(discover.isEmpty)

        let feed = FeedViewModel(service: services.socialService)
        await feed.load()
        XCTAssertFalse(feed.usesPreviewData)
        XCTAssertTrue(feed.isEmpty)
    }

    func testProductionInitializationPreservesRealLocalRecords() async throws {
        let container = try makeContainer()
        let local = SwiftDataScoreService(modelContext: container.mainContext)
        let userID = UUID()
        let score = Score(userId: userID, value: 72, reason: "My own entry")
        try await local.saveScore(score)
        let social = SwiftDataSocialService(modelContext: container.mainContext)
        try await social.submitWorldScore(topicTitle: "My topic", targetId: "main", score: 83, comment: "My reaction")

        let services = AppServices(modelContext: container.mainContext)
        let history = await services.scoreService.getScoreHistory(userId: userID, limit: 365)
        let reactions = await services.socialService.myWorldScores()
        XCTAssertEqual(history.map(\.id), [score.id])
        XCTAssertEqual(history.first?.reason, "My own entry")
        XCTAssertEqual(reactions.count, 1)
        XCTAssertEqual(reactions.first?.score, 83)
    }

    func testWorldNetworkFailureNeverFallsBackToSampleTopics() async {
        ReleaseAuditURLProtocol.handler = { _ in (503, Data()) }
        defer { ReleaseAuditURLProtocol.handler = nil }
        let client = SupabaseHTTPClient(
            config: SupabaseConfig(baseURL: URL(string: "https://production-data-tests.invalid")!, anonKey: "test"),
            tokenProvider: nil, session: ReleaseAuditURLProtocol.session()
        )
        let vm = WorldFeedViewModel(service: MockSocialService(), world: RemoteWorldService(client: client, currentUserID: { nil }))
        await vm.load()
        XCTAssertTrue(vm.topics.isEmpty)
        XCTAssertNotNil(vm.transientError)
        XCTAssertFalse(vm.usesPreviewData)
        XCTAssertFalse(vm.canLoadMoreTopics)

        let realTopic = WorldTopic(id: UUID(), category: .work, title: "A server topic", emoji: "💼",
                                   globalScore: 0, scoreDelta: 0, postsCount: 0, lastActivityAt: .now, heat: .fresh)
        vm.topics = [realTopic]
        await vm.refresh()
        XCTAssertEqual(vm.topics.map(\.id), [realTopic.id])
    }

    func testUnknownUserDoesNotImpersonateCurrentUser() async {
        let user = User(username: "actual_user", email: "")
        let service = MockUserService(seedCurrentUser: user)
        let unknown = await service.getUser(id: UUID())
        let current = await service.getUser(id: user.id)
        XCTAssertNil(unknown)
        XCTAssertEqual(current?.id, user.id)
    }

    func testInvalidSamplePaginationIsSafe() {
        XCTAssertTrue(SocialSeed.feedPage(page: 1, pageSize: 0).isEmpty)
        XCTAssertTrue(SocialSeed.worldPostsPage(page: -1, pageSize: 8).isEmpty)
    }
}
