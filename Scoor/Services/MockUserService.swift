//
//  MockUserService.swift
//  Scoor
//

import Foundation

final class MockUserService: UserServiceProtocol {
    private var currentUser: User
    private var users: [UUID: User] = [:]
    /// Onboarding에서 이모지 아바타로 설정한 글리프 (옵션). UI에서만 사용.
    private(set) var avatarEmoji: String?

    /// Default init for app/runtime. 가입 직후 닉네임은 AppStorage에서 시드.
    init() {
        let defaults = UserDefaults.standard
        let savedName = defaults.string(forKey: "scoor.chosenUsername")
        let username = savedName?.isEmpty == false ? savedName! : "scoor_user"

        // Stable identity across launches. Without this the user id was regenerated
        // on every launch, orphaning persisted scores (they are keyed by userId) so
        // they vanished after an app restart. Persist and reuse the id.
        let idKey = "scoor.currentUserId"
        let userId: UUID
        if let raw = defaults.string(forKey: idKey), let parsed = UUID(uuidString: raw) {
            userId = parsed
        } else {
            userId = UUID()
            defaults.set(userId.uuidString, forKey: idKey)
        }

        let savedBio = defaults.string(forKey: "scoor.userBio")
        let defaultUser = User(id: userId, username: username, email: "user@scoor.app", bio: savedBio)
        currentUser = defaultUser
        users[defaultUser.id] = defaultUser
        avatarEmoji = defaults.string(forKey: "scoor.chosenAvatarEmoji")
    }

    /// Use for previews: set current user and optional extra users (e.g. guestbook authors).
    init(seedCurrentUser: User? = nil, seedUsers: [User] = []) {
        if let seed = seedCurrentUser {
            currentUser = seed
            users[seed.id] = seed
        } else {
            let defaultUser = User(username: "scoor_user", email: "user@scoor.app")
            currentUser = defaultUser
            users[defaultUser.id] = defaultUser
        }
        for u in seedUsers where users[u.id] == nil {
            users[u.id] = u
        }
    }

    func getCurrentUser() async -> User? {
        currentUser
    }

    func getUser(id: UUID) async -> User? {
        users[id] ?? currentUser
    }

    func updateUsername(_ name: String) async {
        currentUser.username = name
        users[currentUser.id] = currentUser
        UserDefaults.standard.set(name, forKey: "scoor.chosenUsername")
    }

    func updateAvatarEmoji(_ emoji: String?) async {
        avatarEmoji = emoji
        if let emoji {
            UserDefaults.standard.set(emoji, forKey: "scoor.chosenAvatarEmoji")
        } else {
            UserDefaults.standard.removeObject(forKey: "scoor.chosenAvatarEmoji")
        }
    }

    func updateBio(_ bio: String?) async {
        let trimmed = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty == false) ? trimmed : nil
        currentUser.bio = value
        users[currentUser.id] = currentUser
        if let value {
            UserDefaults.standard.set(value, forKey: "scoor.userBio")
        } else {
            UserDefaults.standard.removeObject(forKey: "scoor.userBio")
        }
    }
}
