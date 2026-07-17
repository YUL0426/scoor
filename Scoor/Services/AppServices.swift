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

    /// Designated init. Defaults to mock services so SwiftUI previews keep working.
    init(
        scoreService: ScoreServiceProtocol = MockScoreService(),
        userService: UserServiceProtocol = MockUserService(),
        guestbookService: GuestbookServiceProtocol = MockGuestbookService(),
        notificationService: NotificationServiceProtocol = MockNotificationService(),
        socialService: SocialServiceProtocol = MockSocialService(),
        moodAnalyzer: MoodAnalyzing = DisabledMoodAnalyzer()
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.guestbookService = guestbookService
        self.notificationService = notificationService
        self.socialService = socialService
        self.moodAnalyzer = moodAnalyzer
    }

    /// Production init — backs scores with the app's SwiftData container so they
    /// survive app restarts. User/guestbook stay mock for now (out of Sprint 0 scope).
    /// Notifications use the real `UNUserNotificationCenter`-backed service.
    /// Social interactions (likes/comments/world scores/follows) persist via SwiftData.
    @MainActor
    convenience init(modelContext: ModelContext) {
        self.init(
            scoreService: SwiftDataScoreService(modelContext: modelContext),
            notificationService: LocalNotificationService(),
            socialService: SwiftDataSocialService(modelContext: modelContext)
        )
    }
}
