//
//  User.swift
//  Scoor
//

import Foundation

struct User: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var email: String
    var avatarURL: URL?
    var bio: String?
    /// Optional self-described gender (e.g. "여성"/"남성"/"비공개"). Nil = 설정 안 함.
    var gender: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        email: String,
        avatarURL: URL? = nil,
        bio: String? = nil,
        gender: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.bio = bio
        self.gender = gender
        self.createdAt = createdAt
    }
}
