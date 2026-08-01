//
//  RemoteWorldIntegrationTests.swift
//  ScoorTests
//
//  실서버를 실제로 호출하는 통합 테스트.
//
//  다른 테스트와 달리 네트워크를 탄다. 프로비저닝되지 않은 빌드(CI, 신규 체크아웃)
//  에서는 조용히 건너뛴다 — 자격증명 없이도 테스트 스위트가 초록이어야 한다.
//

import XCTest
import SwiftData
@testable import Scoor

final class RemoteWorldIntegrationTests: XCTestCase {

    /// 백엔드가 없으면 건너뛴다.
    private func requireConfig() throws -> SupabaseConfig {
        try XCTSkipIf(SupabaseConfig.current == nil, "백엔드 미설정 — 통합 테스트 건너뜀")
        return SupabaseConfig.current!
    }

    @MainActor
    func testLoadTopicsAgainstLiveServer() async throws {
        let config = try requireConfig()
        // 익명(비로그인) 상태를 그대로 재현한다 — 게스트도 World를 볼 수 있어야 한다.
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil)
        let service = RemoteWorldService(client: client, currentUserID: { nil })

        let topics = try await service.loadTopics()

        XCTAssertFalse(topics.isEmpty, "서버에 큐레이션된 토픽이 있어야 한다")
        print("[Integration] 토픽 \(topics.count)건: \(topics.map(\.title))")
    }

    @MainActor
    func testLoadReactionsAgainstLiveServer() async throws {
        let config = try requireConfig()
        let client = SupabaseHTTPClient(config: config, tokenProvider: nil)
        let service = RemoteWorldService(client: client, currentUserID: { nil })

        let topics = try await service.loadTopics()
        let topic = try XCTUnwrap(topics.first)
        // 반응이 0건이어도 성공이어야 한다 — 콜드 스타트에서는 그게 정상이다.
        let reactions = try await service.reactions(topicId: topic.id)
        print("[Integration] '\(topic.title)' 반응 \(reactions.count)건")
    }
}

// MARK: - 앱과 동일한 구성

extension RemoteWorldIntegrationTests {

    /// 앱이 실제로 쓰는 조합: @MainActor AuthService를 토큰 공급자로 물린 채
    /// @MainActor에서 호출한다. 위의 두 테스트는 tokenProvider가 nil이라
    /// 이 경로를 한 번도 지나지 않았다.
    @MainActor
    func testLoadTopicsWithAuthServiceAsTokenProvider() async throws {
        let config = try requireConfig()
        let auth = AuthService()
        let client = SupabaseHTTPClient(config: config, tokenProvider: auth)
        let service = RemoteWorldService(client: client, currentUserID: { auth.currentSession?.userID })

        let topics = try await service.loadTopics()
        XCTAssertFalse(topics.isEmpty)
        print("[Integration] AuthService 물린 상태에서도 토픽 \(topics.count)건")
    }
}

// MARK: - 배선 확인

final class AppServicesWiringTests: XCTestCase {

    /// 백엔드가 설정되어 있으면 AppServices가 Remote 스택을 실제로 구성해야 한다.
    /// 이게 nil이면 서비스가 아무리 잘 동작해도 화면에는 시드가 뜬다.
    @MainActor
    func testProductionInitBuildsRemoteStackWhenProvisioned() throws {
        try XCTSkipIf(SupabaseConfig.current == nil, "백엔드 미설정 — 건너뜀")

        let container = try ModelContainer(
            for: ScoreModel.self, LikeRecord.self, CommentRecord.self,
            WorldScoreRecord.self, FollowRecord.self, GuestbookRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let auth = AuthService()
        let services = AppServices(modelContext: container.mainContext, authService: auth)

        XCTAssertNotNil(services.worldService, "worldService가 구성되지 않았다")
        XCTAssertNotNil(services.moderationService, "moderationService가 구성되지 않았다")
        XCTAssertNotNil(services.remoteScoreService, "remoteScoreService가 구성되지 않았다")
        XCTAssertTrue(services.isBackendBacked)
    }

    /// authService가 없으면(프리뷰/테스트) 로컬 스택만 남아야 한다.
    @MainActor
    func testFallsBackToLocalStackWithoutAuthService() throws {
        let container = try ModelContainer(
            for: ScoreModel.self, LikeRecord.self, CommentRecord.self,
            WorldScoreRecord.self, FollowRecord.self, GuestbookRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let services = AppServices(modelContext: container.mainContext)
        XCTAssertNil(services.worldService)
        XCTAssertFalse(services.isBackendBacked)
    }
}
