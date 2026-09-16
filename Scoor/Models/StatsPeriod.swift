//
//  StatsPeriod.swift
//  Scoor
//
//  Statistics scope (design: only Weekly + Monthly segments).
//

import Foundation

enum StatsPeriod: String, CaseIterable {
    case daily
    case weekly
    case monthly

    var label: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }

    var headerTitle: String {
        switch self {
        case .daily: return String(localized: "TODAY")
        case .weekly: return String(localized: "Advanced Insights")
        case .monthly: return String(localized: "Monthly Pattern")
        }
    }
}

struct ScoreStatistics {
    let period: StatsPeriod
    let averageScore: Double
    let highestScore: Int
    let lowestScore: Int
    let totalEntries: Int
    let currentStreak: Int
    let bestStreak: Int
    let scores: [Score]
}
