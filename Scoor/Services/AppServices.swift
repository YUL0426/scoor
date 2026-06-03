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
    @Published private(set) var version: Int = 0

    /// Designated init. Defaults to mock services so SwiftUI previews keep working.
    init(
        scoreService: ScoreServiceProtocol = MockScoreService(),
        userService: UserServiceProtocol = MockUserService(),
        guestbookService: GuestbookServiceProtocol = MockGuestbookService()
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.guestbookService = guestbookService
    }

    /// Production init — backs scores with the app's SwiftData container so they
    /// survive app restarts. User/guestbook stay mock for now (out of Sprint 0 scope).
    @MainActor
    convenience init(modelContext: ModelContext) {
        self.init(scoreService: SwiftDataScoreService(modelContext: modelContext))
    }
}
