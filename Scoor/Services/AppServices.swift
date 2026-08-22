//
//  AppServices.swift
//  Scoor
//
//  Container for mock services; inject via .environmentObject().
//

import Combine
import Foundation
import SwiftData
import SwiftUI

final class AppServices: ObservableObject {
    let scoreService: ScoreServiceProtocol
    let userService: UserServiceProtocol
    let guestbookService: GuestbookServiceProtocol
    let notificationService: NotificationServiceProtocol
    /// 소셜 레이어(피드/월드/좋아요/댓글/탐색) 데이터 서비스.
    let socialService: SocialServiceProtocol
    /// 점수+사유 → 파생 감정(mood) 분석 시임(seam). 기본값은 비활성화
    /// (`DisabledMoodAnalyzer`)이라 런타임에는 감정을 만들지 않는다 — 규칙기반/AI
    /// 구현으로 교체하면 동일 인터페이스로 자동 점등된다. (Sprint 2-B 연결 지점)
    let moodAnalyzer: MoodAnalyzing
    @Published private(set) var version: Int = 0

    /// Backend-backed services. Nil when `SupabaseConfig` is not provisioned, which
    /// is how the app stays fully functional with no server (spec-13 §5).
    private(set) var remoteScoreService: RemoteScoreService?
    private(set) var worldService: RemoteWorldService?
    private(set) var moderationService: RemoteModerationService?
    /// 서버 피드 (spec-13 §3.3). nil이면 Feed 탭은 로컬 시드 경로로 남는다.
    private(set) var feedService: RemoteFeedService?

    /// Whether this build syncs to a backend at all — drives the Settings sync row.
    var isBackendBacked: Bool { remoteScoreService != nil }

    /// Adopts pre-login data on sign-in (spec-13 §7). Present even with no backend:
    /// the account id changes there too, so the local re-key is still required.
    private(set) var accountMigrator: AccountMigrator?

    /// Designated init. Defaults to mock services so SwiftUI previews keep working.
    init(
        scoreService: ScoreServiceProtocol = MockScoreService(),
        userService: UserServiceProtocol = MockUserService(),
        guestbookService: GuestbookServiceProtocol = MockGuestbookService(),
        notificationService: NotificationServiceProtocol = MockNotificationService(),
        socialService: SocialServiceProtocol = MockSocialService(),
        moodAnalyzer: MoodAnalyzing = DisabledMoodAnalyzer(),
        remoteScoreService: RemoteScoreService? = nil,
        worldService: RemoteWorldService? = nil,
        moderationService: RemoteModerationService? = nil,
        feedService: RemoteFeedService? = nil
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.guestbookService = guestbookService
        self.notificationService = notificationService
        self.socialService = socialService
        self.moodAnalyzer = moodAnalyzer
        self.remoteScoreService = remoteScoreService
        self.worldService = worldService
        self.moderationService = moderationService
        self.feedService = feedService
    }

    /// Production init — backs scores, guestbook, and social interactions with the
    /// app's SwiftData container so they survive app restarts. User profile stays
    /// local-first (UserDefaults/Keychain) until a backend profile API exists.
    /// Notifications use the real `UNUserNotificationCenter`-backed service.
    ///
    /// When the backend is provisioned *and* an auth service can supply tokens,
    /// scores are wrapped in `RemoteScoreService` — a decorator, so SwiftData
    /// stays the source of truth and every read still comes from disk. Passing no
    /// auth service (previews, tests) leaves the local stack untouched.
    @MainActor
    convenience init(modelContext: ModelContext, authService: AuthService? = nil) {
        let localScores = SwiftDataScoreService(modelContext: modelContext)

        var remoteScores: RemoteScoreService?
        var world: RemoteWorldService?
        var moderation: RemoteModerationService?
        var feed: RemoteFeedService?
        var httpClient: SupabaseHTTPClient?

        if let config = SupabaseConfig.current, let authService {
            let client = SupabaseHTTPClient(config: config, tokenProvider: authService)
            httpClient = client
            remoteScores = RemoteScoreService(local: localScores, client: client)
            // Reads the id at call time rather than capturing it: the session can
            // change (sign-out, account switch) while these services live on.
            let currentUserID: () -> UUID? = { [weak authService] in
                authService?.currentSession?.userID
            }
            world = RemoteWorldService(client: client, currentUserID: currentUserID)
            moderation = RemoteModerationService(client: client, currentUserID: currentUserID)
            feed = RemoteFeedService(client: client, currentUserID: currentUserID)
        }

        let guestbook = SwiftDataGuestbookService(modelContext: modelContext)
        self.init(
            scoreService: remoteScores ?? localScores,
            guestbookService: guestbook,
            notificationService: LocalNotificationService(),
            socialService: SwiftDataSocialService(modelContext: modelContext),
            remoteScoreService: remoteScores,
            worldService: world,
            moderationService: moderation,
            feedService: feed
        )
        self.accountMigrator = AccountMigrator(
            scoreService: scoreService,
            guestbookService: guestbook,
            userService: userService,
            remoteScoreService: remoteScores,
            client: httpClient
        )
    }

    /// Push queued score writes and pull anything newer from other devices.
    /// Safe to call often — overlapping runs collapse, and it is a no-op with no
    /// backend or no signed-in user.
    @MainActor
    func syncScores(userId: UUID?) {
        guard let userId, let remoteScoreService else { return }
        remoteScoreService.sync(userId: userId)
    }

    /// Call right after a sign-in has been applied to the profile: adopt whatever
    /// was recorded before the account existed, then sync (spec-13 §7).
    ///
    /// - Parameter previousLocalUserID: the id local rows were keyed to *before*
    ///   `applyAuthenticatedIdentity` swapped it.
    @MainActor
    func adoptSignedInAccount(previousLocalUserID: UUID?, accountUserID: UUID) async {
        await accountMigrator?.migrateIfNeeded(from: previousLocalUserID, to: accountUserID)
        syncScores(userId: accountUserID)
    }

    /// Timestamp of the last successful pull, for the Settings sync row.
    @MainActor
    func lastSyncedAt() async -> Date? {
        await remoteScoreService?.lastSyncedAt()
    }
}
