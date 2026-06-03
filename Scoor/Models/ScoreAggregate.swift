//
//  ScoreAggregate.swift
//  Scoor
//
//  Aggregated score data for map bubbles.
//

import Foundation

struct ScoreAggregate: Codable, Identifiable {
    let id: UUID
    let location: Location
    let averageScore: Double
    let totalCount: Int
    let period: Date

    init(
        id: UUID = UUID(),
        location: Location,
        averageScore: Double,
        totalCount: Int,
        period: Date = .now
    ) {
        self.id = id
        self.location = location
        self.averageScore = averageScore
        self.totalCount = totalCount
        self.period = period
    }
}
