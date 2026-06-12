//
//  MockUserService.swift
//  Scoor
//
//  Local-first user/profile store. Persists identity + profile fields to
//  UserDefaults and the avatar image to the Documents directory. Acts as the
//  app's UserService until a backend profile API is wired in; the public API is
//  already shaped for that swap (see UserServiceProtocol account/profile methods).
//

import Foundation

final class MockUserService: UserServiceProtocol {
    private var currentUser: User
    private var users: [UUID: User] = [:]
    /// Onboarding에서 이모지 아바타로 설정한 글리프 (옵션). UI에서만 사용.
    private(set) var avatarEmoji: String?

    // MARK: - Persistence keys
    private enum Key {
        static let username = "scoor.chosenUsername"
        static let userId   = "scoor.currentUserId"
        static let bio      = "scoor.userBio"
        static let email    = "scoor.userEmail"
        static let gender   = "scoor.userGender"
        static let avatarEmoji = "scoor.chosenAvatarEmoji"
    }

    /// Default init for app/runtime. 가입 직후 닉네임은 AppStorage에서 시드.
    init() {
        let defaults = UserDefaults.standard
        let savedName = defaults.string(forKey: Key.username)
        let username = savedName?.isEmpty == false ? savedName! : "scoor_user"

        // Stable identity across launches. Without this the user id was regenerated
        // on every launch, orphaning persisted scores (they are keyed by userId) so
        // they vanished after an app restart. Persist and reuse the id.
        let userId: UUID
        if let raw = defaults.string(forKey: Key.userId), let parsed = UUID(uuidString: raw) {
            userId = parsed
        } else {
            userId = UUID()
            defaults.set(userId.uuidString, forKey: Key.userId)
        }

        let savedBio = defaults.string(forKey: Key.bio)
        // Email is seeded from a real auth session when present, else a fallback.
        let email = defaults.string(forKey: Key.email)
            ?? defaults.string(forKey: "scoor.authEmail")
            ?? "user@scoor.app"
        let gender = defaults.string(forKey: Key.gender)
        let avatarURL = Self.avatarFileURLIfExists()

        let defaultUser = User(
            id: userId,
            username: username,
            email: email,
            avatarURL: avatarURL,
            bio: savedBio,
            gender: gender
        )
        currentUser = defaultUser
        users[defaultUser.id] = defaultUser
        avatarEmoji = defaults.string(forKey: Key.avatarEmoji)
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

    // MARK: - Reads

    func getCurrentUser() async -> User? { currentUser }

    func getUser(id: UUID) async -> User? { users[id] ?? currentUser }

    func currentAvatarEmoji() async -> String? { avatarEmoji }

    // MARK: - Profile field updates

    func updateUsername(_ name: String) async {
        currentUser.username = name
        users[currentUser.id] = currentUser
        UserDefaults.standard.set(name, forKey: Key.username)
    }

    func updateAvatarEmoji(_ emoji: String?) async {
        avatarEmoji = emoji
        if let emoji {
            UserDefaults.standard.set(emoji, forKey: Key.avatarEmoji)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.avatarEmoji)
        }
    }

    func updateBio(_ bio: String?) async {
        let trimmed = bio?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty == false) ? trimmed : nil
        currentUser.bio = value
        users[currentUser.id] = currentUser
        if let value {
            UserDefaults.standard.set(value, forKey: Key.bio)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.bio)
        }
    }

    func updateEmail(_ email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentUser.email = trimmed
        users[currentUser.id] = currentUser
        UserDefaults.standard.set(trimmed, forKey: Key.email)
    }

    func updateGender(_ gender: String?) async {
        let trimmed = gender?.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (trimmed?.isEmpty == false) ? trimmed : nil
        currentUser.gender = value
        users[currentUser.id] = currentUser
        if let value {
            UserDefaults.standard.set(value, forKey: Key.gender)
        } else {
            UserDefaults.standard.removeObject(forKey: Key.gender)
        }
    }

    func updateAvatarImage(_ data: Data?) async {
        let url = Self.avatarFileURL()
        if let data {
            try? data.write(to: url, options: .atomic)
            // Clearing the emoji avatar when a real image is set keeps display logic simple.
            avatarEmoji = nil
            UserDefaults.standard.removeObject(forKey: Key.avatarEmoji)
            currentUser.avatarURL = url
        } else {
            try? FileManager.default.removeItem(at: url)
            currentUser.avatarURL = nil
        }
        users[currentUser.id] = currentUser
    }

    // MARK: - Account lifecycle

    func applyAuthenticatedIdentity(provider: String, userID: UUID, email: String?, displayName: String?) async {
        let defaults = UserDefaults.standard
        // Adopt the account's stable id so scores/profile key off the real account.
        defaults.set(userID.uuidString, forKey: Key.userId)

        var updated = currentUser
        updated = User(
            id: userID,
            username: currentUser.username,
            email: email ?? currentUser.email,
            avatarURL: currentUser.avatarURL,
            bio: currentUser.bio,
            gender: currentUser.gender,
            createdAt: currentUser.createdAt
        )
        currentUser = updated
        users[updated.id] = updated

        if let email, !email.isEmpty {
            defaults.set(email, forKey: Key.email)
        }
        defaults.set(provider, forKey: "scoor.authProvider")
    }

    func signOutCurrentUser() async {
        let defaults = UserDefaults.standard
        for key in [Key.username, Key.userId, Key.bio, Key.email, Key.gender, Key.avatarEmoji,
                    "scoor.authProvider", "scoor.authEmail"] {
            defaults.removeObject(forKey: key)
        }
        try? FileManager.default.removeItem(at: Self.avatarFileURL())

        let freshId = UUID()
        defaults.set(freshId.uuidString, forKey: Key.userId)
        let fresh = User(id: freshId, username: "scoor_user", email: "user@scoor.app")
        currentUser = fresh
        users = [freshId: fresh]
        avatarEmoji = nil
    }

    // MARK: - Avatar storage helpers

    private static func avatarFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("scoor-avatar.jpg")
    }

    private static func avatarFileURLIfExists() -> URL? {
        let url = avatarFileURL()
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
