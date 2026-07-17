//
//  UserServiceProtocol.swift
//  Scoor
//

import Foundation

protocol UserServiceProtocol {
    func getCurrentUser() async -> User?
    func getUser(id: UUID) async -> User?
    func updateUsername(_ name: String) async
    func updateAvatarEmoji(_ emoji: String?) async
    func updateBio(_ bio: String?) async

    // MARK: - Account & profile (S1/S5)
    /// Emoji avatar glyph chosen during onboarding (nil if a photo avatar / none).
    func currentAvatarEmoji() async -> String?
    func updateEmail(_ email: String) async
    func updateGender(_ gender: String?) async
    /// Persist an avatar image (JPEG data) locally and reflect it via `avatarURL`.
    /// Pass `nil` to remove the custom avatar.
    func updateAvatarImage(_ data: Data?) async
    /// Map a successful provider sign-in onto the local user identity: adopts the
    /// account's stable id and pre-fills email / display name when available.
    func applyAuthenticatedIdentity(provider: String, userID: UUID, email: String?, displayName: String?) async
    /// Clear the locally cached profile/identity on sign-out.
    func signOutCurrentUser() async
}

extension UserServiceProtocol {
    /// 기본 구현 — 기존 mock/구현체에서 오버라이드하지 않아도 빌드가 깨지지 않게.
    func updateUsername(_ name: String) async {}
    func updateAvatarEmoji(_ emoji: String?) async {}
    func updateBio(_ bio: String?) async {}
    func currentAvatarEmoji() async -> String? { nil }
    func updateEmail(_ email: String) async {}
    func updateGender(_ gender: String?) async {}
    func updateAvatarImage(_ data: Data?) async {}
    func applyAuthenticatedIdentity(provider: String, userID: UUID, email: String?, displayName: String?) async {}
    func signOutCurrentUser() async {}
}
