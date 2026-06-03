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
}

extension UserServiceProtocol {
    /// 기본 구현 — 기존 mock/구현체에서 오버라이드하지 않아도 빌드가 깨지지 않게.
    func updateUsername(_ name: String) async {}
    func updateAvatarEmoji(_ emoji: String?) async {}
    func updateBio(_ bio: String?) async {}
}
