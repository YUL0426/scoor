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
    let createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        email: String,
        avatarURL: URL? = nil,
        bio: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarURL = avatarURL
        self.bio = bio
        self.createdAt = createdAt
    }
}
