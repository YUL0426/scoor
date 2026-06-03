//
//  PreviewData.swift
//  Scoor
//
//  Mock data for SwiftUI Previews and testing.
//  Use with mock services (seed initializers) for consistent previews.
//

import Foundation

enum PreviewData {
    // MARK: - Users

    static let sampleUser = User(
        username: "sarah_lee",
        email: "sarah@example.com"
    )

    /// Additional users (e.g. guestbook authors, feed).
    static let sampleUsers: [User] = [
        sampleUser,
        User(username: "alex_m", email: "alex@example.com"),
        User(username: "jordan_l", email: "jordan@example.com"),
        User(username: "yuki_t", email: "yuki@example.com"),
        User(username: "marcos_b", email: "marcos@example.com"),
        User(username: "sam_k", email: "sam@example.com"),
    ]

    // MARK: - Scores

    static let sampleScore = Score(
        userId: sampleUser.id,
        value: 82,
        reason: "Had a great meeting and finished project!"
    )

    /// Same calendar-day index as production (`ScoreCalendarIndex.entriesByDay(from:)`).
    static var sampleEntriesByDay: [Date: ScoreEntry] {
        ScoreCalendarIndex.entriesByDay(from: sampleScores)
    }

    /// ~30 days of scores for charts and calendar.
    static let sampleScores: [Score] = {
        let calendar = Calendar.current
        return (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            return Score(
                userId: sampleUser.id,
                value: [45, 62, 78, 88, 72, 91, 65, 80, 85, 70, 55, 90, 75, 82, 68, 79, 84, 73, 69, 77, 86, 71, 81, 74, 63, 89, 76, 83, 67, 58][dayOffset % 30],
                reason: dayOffset % 3 == 0 ? "Feeling good" : nil,
                date: date
            )
        }
    }()

    /// Single score for “today” (pre-filled form).
    static let sampleTodaysScore = Score(
        userId: sampleUser.id,
        value: 78,
        reason: "Productive morning, relaxed evening.",
        date: Calendar.current.startOfDay(for: Date())
    )

    // MARK: - Guestbook

    static let sampleGuestbookMessage = GuestbookMessage(
        authorId: sampleUsers[1].id,
        recipientId: sampleUser.id,
        content: "Loved your 99 score yesterday! You're absolutely crushing it this week. Let's get coffee soon! ☕"
    )

    /// Multiple guestbook messages for My Page preview (recipient = sampleUser).
    static let sampleGuestbookMessages: [GuestbookMessage] = {
        let recipientId = sampleUser.id
        let now = Date()
        return [
            GuestbookMessage(authorId: sampleUsers[1].id, recipientId: recipientId, content: "Your consistency is inspiring! 🔥", isPrivate: false, createdAt: now.addingTimeInterval(-3600)),
            GuestbookMessage(authorId: sampleUsers[2].id, recipientId: recipientId, content: "Let's get coffee soon!", isPrivate: false, createdAt: now.addingTimeInterval(-86400)),
            GuestbookMessage(authorId: sampleUsers[3].id, recipientId: recipientId, content: "Private note: You're doing great.", isPrivate: true, createdAt: now.addingTimeInterval(-172800)),
            GuestbookMessage(authorId: sampleUsers[4].id, recipientId: recipientId, content: "That 95 score was well deserved!", isPrivate: false, createdAt: now.addingTimeInterval(-259200)),
        ]
    }()

    /// Display-ready guestbook rows (for previews that bypass service).
    static let sampleGuestbookMessageDisplays: [GuestbookMessageDisplay] = {
        let now = Date()
        return [
            GuestbookMessageDisplay(id: UUID(), authorName: "alex_m", content: "Your consistency is inspiring! 🔥", isPrivate: false, createdAt: now.addingTimeInterval(-3600)),
            GuestbookMessageDisplay(id: UUID(), authorName: "jordan_l", content: "Let's get coffee soon!", isPrivate: false, createdAt: now.addingTimeInterval(-86400)),
            GuestbookMessageDisplay(id: UUID(), authorName: "yuki_t", content: "Private note: You're doing great.", isPrivate: true, createdAt: now.addingTimeInterval(-172800)),
        ]
    }()

    // MARK: - Locations & Aggregates

    static let sampleLocations: [Location] = [
        Location(country: "Korea", city: "Seoul", latitude: 37.5665, longitude: 126.9780),
        Location(country: "USA", city: "New York", latitude: 40.7128, longitude: -74.0060),
        Location(country: "UK", city: "London", latitude: 51.5074, longitude: -0.1278),
        Location(country: "Brazil", city: "São Paulo", latitude: -23.5505, longitude: -46.6333),
        Location(country: "Australia", city: "Sydney", latitude: -33.8688, longitude: 151.2093),
    ]

    static let sampleAggregates: [ScoreAggregate] = sampleLocations.map { location in
        ScoreAggregate(
            location: location,
            averageScore: Double.random(in: 6.0...9.5),
            totalCount: Int.random(in: 50...500)
        )
    }

    // MARK: - Mock Service Helpers

    /// Pre-configured mock services with preview data for use in `#Preview`.
    static func makePreviewServices() -> (ScoreServiceProtocol, UserServiceProtocol, GuestbookServiceProtocol) {
        let scoreService = MockScoreService(seedScores: PreviewData.sampleScores)
        let userService = MockUserService(seedCurrentUser: PreviewData.sampleUser, seedUsers: PreviewData.sampleUsers)
        let guestbookService = MockGuestbookService(seedMessages: PreviewData.sampleGuestbookMessages)
        return (scoreService, userService, guestbookService)
    }
}
