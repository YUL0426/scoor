//
//  Mood+Emotion.swift
//  Scoor
//
//  Sprint 2-A — reuses the existing Feed `Mood` enum as the structured emotion
//  tag for a daily Scoor. Kept in its own file so the Feed domain
//  (`FeedModels.swift`) is untouched.
//
//  • `Codable` lets `Score` (Codable) carry an optional `Mood`.
//  • Display helpers (emoji / SF Symbol / tint) drive the emotion chips and
//    badges across Score input, Home, Calendar and My Page.
//

import SwiftUI

// Raw-value (String) enum → Codable is synthesized from the rawValue.
extension Mood: Codable {}

extension Mood {
    /// Small emoji used in compact badges/chips.
    var emoji: String {
        switch self {
        case .happy:    return "😊"
        case .burnout:  return "🥵"
        case .lonely:   return "🥲"
        case .calm:     return "😌"
        case .healing:  return "🌿"
        case .work:     return "💼"
        case .love:     return "❤️"
        case .night:    return "🌙"
        case .students: return "📚"
        }
    }

    /// SF Symbol fallback for monochrome contexts.
    var symbol: String {
        switch self {
        case .happy:    return "face.smiling"
        case .burnout:  return "flame"
        case .lonely:   return "cloud.rain"
        case .calm:     return "leaf"
        case .healing:  return "heart.text.square"
        case .work:     return "briefcase"
        case .love:     return "heart"
        case .night:    return "moon.stars"
        case .students: return "book"
        }
    }

    /// Accent tint for the chip when selected.
    var tint: Color {
        switch self {
        case .happy:    return Color(hex: "F4A742")
        case .burnout:  return Color(hex: "E5533B")
        case .lonely:   return Color(hex: "6B7FB3")
        case .calm:     return Color(hex: "5FA8A0")
        case .healing:  return Color(hex: "5FB37A")
        case .work:     return Color(hex: "8A8F98")
        case .love:     return Color(hex: "E5557F")
        case .night:    return Color(hex: "5C5AA8")
        case .students: return Color(hex: "C79A4B")
        }
    }
}
