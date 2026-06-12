//
//  ScoreModel.swift
//  Scoor
//
//  SwiftData model for local persistence.
//

import Foundation
import SwiftData

@Model
class ScoreModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var value: Int
    var reason: String?
    /// Raw value of the optional `Mood` emotion tag (Sprint 2-A).
    /// Stored as an optional String so adding it is a purely additive,
    /// automatic lightweight migration — existing rows decode to `nil`.
    var moodRaw: String?
    var date: Date
    var locationId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        value: Int,
        reason: String? = nil,
        moodRaw: String? = nil,
        date: Date = .now,
        locationId: UUID? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.userId = userId
        self.value = value
        self.reason = reason
        self.moodRaw = moodRaw
        self.date = date
        self.locationId = locationId
        self.createdAt = createdAt
    }

    /// Build a persistent model from a value-type `Score` (single source of mapping).
    convenience init(from score: Score) {
        self.init(
            id: score.id,
            userId: score.userId,
            value: score.value,
            reason: score.reason,
            moodRaw: score.mood?.rawValue,
            date: score.date,
            locationId: score.locationId,
            createdAt: score.createdAt
        )
    }

    /// Copy the mutable fields of a `Score` onto an existing model (used for in-place updates).
    func apply(_ score: Score) {
        value = score.value
        reason = score.reason
        moodRaw = score.mood?.rawValue
        locationId = score.locationId
    }

    // Convert to value type
    func toScore() -> Score {
        Score(
            id: id,
            userId: userId,
            value: value,
            reason: reason,
            mood: moodRaw.flatMap(Mood.init(rawValue:)),
            date: date,
            locationId: locationId,
            createdAt: createdAt
        )
    }
}
