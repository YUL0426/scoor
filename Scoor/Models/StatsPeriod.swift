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
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var headerTitle: String {
        switch self {
        case .daily: return "Today"
        case .weekly: return "Advanced Insights"
        case .monthly: return "Monthly Pattern"
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
