//
//  MyPageViewModel.swift
//  Scoor
//
//  Profile, calendar score visualization, guestbook.
//

import Foundation
import Combine

struct GuestbookMessageDisplay: Identifiable {
    let id: UUID
    let authorName: String
    let content: String
    let isPrivate: Bool
    let createdAt: Date
}

@MainActor
final class MyPageViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    /// Emoji avatar glyph (onboarding) — used when no photo avatar is set.
    @Published private(set) var avatarEmoji: String?
    /// Sign-in provider for the account badge on the profile header.
    @Published private(set) var authProvider: AuthProvider?
    /// Same day-keying as `StatsViewModel` / `ScoreCalendarIndex` (`Calendar.current.startOfDay`).
    @Published private(set) var entriesByDay: [Date: ScoreEntry] = [:]
    @Published var displayedMonth: Date = Date()
    @Published private(set) var monthlyAverage: Int?
    /// Most frequently recorded emotion in the displayed month (Sprint 2-A).
    @Published private(set) var monthlyTopMood: Mood?
    @Published private(set) var monthlyTopMoodCount: Int = 0
    @Published private(set) var guestbookMessages: [GuestbookMessageDisplay] = []
    @Published var guestbookComposeText: String = ""
    @Published private(set) var isPostingGuestbook = false
    @Published private(set) var isLoading = false

    private let scoreService: ScoreServiceProtocol
    private let userService: UserServiceProtocol
    private let guestbookService: GuestbookServiceProtocol
    private let calendar = Calendar.current

    init(
        scoreService: ScoreServiceProtocol,
        userService: UserServiceProtocol,
        guestbookService: GuestbookServiceProtocol
    ) {
        self.scoreService = scoreService
        self.userService = userService
        self.guestbookService = guestbookService
    }

    var recipientId: UUID? { currentUser?.id }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let user = await userService.getCurrentUser() else {
            currentUser = nil
            return
        }
        currentUser = user
        avatarEmoji = await userService.currentAvatarEmoji()
        authProvider = UserDefaults.standard.string(forKey: "scoor.authProvider").flatMap(AuthProvider.init(rawValue:))

        let history = await scoreService.getScoreHistory(userId: user.id, limit: 365)
        entriesByDay = ScoreCalendarIndex.entriesByDay(from: history, calendar: calendar)
        #if DEBUG
        print("[Scoor] MyPageViewModel.load userId=\(user.id) historyCount=\(history.count) distinctDays=\(entriesByDay.count)")
        #endif
        updateMonthlyAverage()

        await loadGuestbook()
    }

    func loadGuestbook() async {
        guard let recipientId = currentUser?.id else { return }
        let messages = await guestbookService.getMessages(recipientId: recipientId, includePrivate: true)
        var display: [GuestbookMessageDisplay] = []
        for msg in messages {
            let author = await userService.getUser(id: msg.authorId)
            display.append(GuestbookMessageDisplay(
                id: msg.id,
                authorName: author?.username ?? "Unknown",
                content: msg.content,
                isPrivate: msg.isPrivate,
                createdAt: msg.createdAt
            ))
        }
        guestbookMessages = display.sorted { $0.createdAt > $1.createdAt }
    }

    func postGuestbookMessage() async {
        guard let authorId = currentUser?.id, let recipientId = recipientId else { return }
        let content = guestbookComposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isPostingGuestbook = true
        defer { isPostingGuestbook = false }

        do {
            try await guestbookService.postMessage(
                authorId: authorId,
                recipientId: recipientId,
                content: content,
                isPrivate: false
            )
            guestbookComposeText = ""
            await loadGuestbook()
        } catch {
            // Could show error toast
        }
    }

    /// Delete a guestbook entry on the current user's page, then reload (BUG-010).
    func deleteGuestbookMessage(_ message: GuestbookMessageDisplay) async {
        do {
            try await guestbookService.deleteMessage(id: message.id)
            await loadGuestbook()
        } catch {
            // Could show error toast
        }
    }

    /// Delete the score recorded on the given calendar day (if any), then reload.
    /// Resolves the underlying `Score` via the service so deletion works the same
    /// for both the mock and SwiftData backends.
    func deleteScore(for date: Date) async {
        guard let user = currentUser else { return }
        let day = calendar.startOfDay(for: date)
        let scores = await scoreService.getScoresForDate(userId: user.id, date: day)
        guard !scores.isEmpty else { return }
        for score in scores {
            try? await scoreService.deleteScore(score)
        }
        #if DEBUG
        print("[Scoor] MyPageViewModel.deleteScore day=\(day) removed=\(scores.count)")
        #endif
        await load()
    }

    func entry(for date: Date) -> ScoreEntry? {
        let day = calendar.startOfDay(for: date)
        return entriesByDay[day]
    }

    func previousMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newMonth
            updateMonthlyAverage()
        }
    }

    func nextMonth() {
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newMonth
            updateMonthlyAverage()
        }
    }

    private func updateMonthlyAverage() {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? displayedMonth
        let inMonth = entriesByDay.filter { $0.key >= start && $0.key <= end }
        if inMonth.isEmpty {
            monthlyAverage = nil
        } else {
            let sum = inMonth.values.map(\.score).reduce(0, +)
            monthlyAverage = Int(round(Double(sum) / Double(inMonth.count)))
        }

        // Dominant emotion of the month (most frequent mood tag).
        var counts: [Mood: Int] = [:]
        for entry in inMonth.values {
            if let mood = entry.mood { counts[mood, default: 0] += 1 }
        }
        if let top = counts.max(by: { $0.value < $1.value }) {
            monthlyTopMood = top.key
            monthlyTopMoodCount = top.value
        } else {
            monthlyTopMood = nil
            monthlyTopMoodCount = 0
        }
    }
}
