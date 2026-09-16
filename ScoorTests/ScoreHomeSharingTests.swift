import XCTest
@testable import Scoor

@MainActor
final class ScoreHomeSharingTests: XCTestCase {
    func testSharedScorePublishesScoreAndReason() async {
        let user = User(username: "home-share-test", email: "test@scoor.app")
        let scores = MockScoreService()
        let publisher = HomeFeedPublisherSpy()
        let viewModel = ScoreInputViewModel(
            scoreService: scores,
            userService: MockUserService(seedCurrentUser: user),
            homeFeedPublisher: publisher
        )

        await viewModel.loadTodaysScore()
        viewModel.updateScore(82)
        viewModel.setReason("친구와 오래 산책했다")
        viewModel.shareToHome = true
        await viewModel.submitScore()

        XCTAssertTrue(viewModel.isSubmitted)
        XCTAssertEqual(publisher.lastScore?.value, 82)
        XCTAssertEqual(publisher.lastScore?.reason, "친구와 오래 산책했다")
        XCTAssertEqual(publisher.lastShared, true)
    }

    func testShareFailureDoesNotLosePrivateScore() async {
        let user = User(username: "home-share-failure", email: "test@scoor.app")
        let scores = MockScoreService()
        let publisher = HomeFeedPublisherSpy(error: TestError.failed)
        let viewModel = ScoreInputViewModel(
            scoreService: scores,
            userService: MockUserService(seedCurrentUser: user),
            homeFeedPublisher: publisher
        )

        await viewModel.loadTodaysScore()
        viewModel.updateScore(43)
        viewModel.setReason("조금 지친 하루")
        viewModel.shareToHome = true
        await viewModel.submitScore()

        let saved = await scores.getTodaysScore(userId: user.id)
        XCTAssertEqual(saved?.value, 43)
        XCTAssertFalse(viewModel.isSubmitted)
        XCTAssertEqual(viewModel.feedbackMessage, "점수는 저장됐지만 홈 공유에 실패했어요. 다시 시도해주세요.")
    }

    func testEmptyReasonCannotRemainShared() async {
        let viewModel = ScoreInputViewModel(
            scoreService: MockScoreService(),
            userService: MockUserService(),
            homeFeedPublisher: HomeFeedPublisherSpy()
        )
        viewModel.setReason("공개할 이유")
        viewModel.shareToHome = true
        viewModel.setReason("   ")

        XCTAssertFalse(viewModel.shareToHome)
        XCTAssertFalse(viewModel.canShareToHome)
    }

    func testPrivateScoreDoesNotCallFeedWriter() async {
        let user = User(username: "private-score", email: "test@scoor.app")
        let publisher = HomeFeedPublisherSpy()
        let viewModel = ScoreInputViewModel(
            scoreService: MockScoreService(),
            userService: MockUserService(seedCurrentUser: user),
            homeFeedPublisher: publisher
        )

        await viewModel.loadTodaysScore()
        viewModel.updateScore(67)
        viewModel.setReason("개인 기록")
        await viewModel.submitScore()

        XCTAssertTrue(viewModel.isSubmitted)
        XCTAssertNil(publisher.lastShared)
    }
}

@MainActor
private final class HomeFeedPublisherSpy: HomeFeedPublishing {
    var isAvailable = true
    var lastScore: Score?
    var lastShared: Bool?
    var isShared = false
    let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func isDailyScoreShared(on date: Date) async throws -> Bool { isShared }

    func setDailyScore(_ score: Score, shared: Bool) async throws {
        if let error { throw error }
        lastScore = score
        lastShared = shared
        isShared = shared
    }
}

private enum TestError: Error {
    case failed
}
