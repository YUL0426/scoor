//
//  WorldViewModel.swift
//  Scoor
//
//  Worldwide map + country feed (design: 2. world/worldwide_scoor_map_1–2).
//

import Foundation
import Combine

enum WorldMapScope: String, CaseIterable {
    case global
    case local
}

/// Map annotation: `id` is the navigation / feed key; must match `feedData` keys exactly.
/// `xFraction` / `yFraction` are in image-space (0=west/north, 1=east/south) of the
/// underlying 2:1 equirectangular world map. The view layer maps them to the
/// rendered map rect, so bubbles always sit on the correct geographic location.
struct WorldMapBubble: Identifiable, Hashable {
    let id: String
    let displayName: String
    /// National or city average on the 0–100 scale.
    let averageScore: Int
    /// Image-space x (0=west edge, 1=east edge) — equirectangular projection.
    let xFraction: CGFloat
    /// Image-space y (0=north edge, 1=south edge) — equirectangular projection.
    let yFraction: CGFloat
    /// Primary-filled bubble (e.g. Korea) vs white + red border.
    var filledStyle: Bool

    /// Display style "8.5" — score divided by 10 with one decimal (matches Stitch designs).
    var scoreText: String {
        String(format: "%.1f", Double(averageScore) / 10.0)
    }
}

struct CountryFeedUserEntry: Identifiable {
    let id: UUID
    let displayName: String
    let timeLabel: String
    let reason: String
    let score: Int
    let avatarURL: URL?
    var likeCount: Int
    var liked: Bool
}

@MainActor
final class WorldViewModel: ObservableObject {
    @Published var mapScope: WorldMapScope = .global
    @Published var searchText: String = ""
    @Published var mapScale: CGFloat = 1.0

    static let worldMapImageURL = URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuBOsjN3y_1cBuqDMJ1y4CYBWkeWo-FCwni92Ghb_dAM1rkmDGY6vuM-TGknoQOtFGrvsUz33AEmTqlJM6-5IqF8fEplYlIroN-h9QNauWRHBVcqO_ZcrYUnELATlyycRkvJoLu-z4GpgYfcz8g7IHuipwvclJPoGlnAANGox7Ak091TkS4WBlXtRCx9lQpK4R7sE6O-5TpLSzogrw33nqHSIB2Dg1s_BMnFMf4mUWYrITnlfQsX2fJ1ra6_iBSLsRcFqumwFcvHP-38")!

    // Geographic coordinates → equirectangular image fractions:
    //   xFraction = (longitude + 180) / 360
    //   yFraction = (90 - latitude) / 180
    // Latitude bias of ~+0.04 keeps the bubble *above* the country, so the tail points down at it.
    private static let globalBubbles: [WorldMapBubble] = [
        // USA (~ -98°, 39°)
        WorldMapBubble(id: "USA", displayName: "USA", averageScore: 72, xFraction: 0.228, yFraction: 0.245, filledStyle: false),
        // UK (~ -2°, 54°)
        WorldMapBubble(id: "UK", displayName: "UK", averageScore: 79, xFraction: 0.494, yFraction: 0.155, filledStyle: false),
        // Korea (~ 127°, 37°)
        WorldMapBubble(id: "KOREA", displayName: "KOREA", averageScore: 85, xFraction: 0.853, yFraction: 0.255, filledStyle: true),
        // Nigeria (~ 8°, 10°)
        WorldMapBubble(id: "NG", displayName: "NG", averageScore: 74, xFraction: 0.522, yFraction: 0.40, filledStyle: false),
        // Brazil (~ -53°, -10°)
        WorldMapBubble(id: "BRAZIL", displayName: "BRAZIL", averageScore: 68, xFraction: 0.353, yFraction: 0.515, filledStyle: false),
        // Australia (~ 134°, -25°)
        WorldMapBubble(id: "AUS", displayName: "AUS", averageScore: 81, xFraction: 0.872, yFraction: 0.595, filledStyle: false),
    ]

    // Local (Korea cities) — the screen will reuse the same world map, so positions still
    // need to land on Korea peninsula relative to the full map.
    private static let localBubbles: [WorldMapBubble] = [
        // Seoul (~ 127°, 37.5°)
        WorldMapBubble(id: "SEOUL", displayName: "SEOUL", averageScore: 84, xFraction: 0.853, yFraction: 0.250, filledStyle: true),
        // Busan (~ 129°, 35°)
        WorldMapBubble(id: "BUSAN", displayName: "BUSAN", averageScore: 80, xFraction: 0.858, yFraction: 0.275, filledStyle: false),
        // Daegu (~ 128.6°, 35.9°)
        WorldMapBubble(id: "DAEGU", displayName: "DAEGU", averageScore: 77, xFraction: 0.857, yFraction: 0.265, filledStyle: false),
    ]

    func load() async {
        #if DEBUG
        let list = mapScope == .global ? Self.globalBubbles : Self.localBubbles
        let summary = list.map { "\($0.id)=\($0.displayName)(\($0.averageScore))" }.joined(separator: ", ")
        print("[Scoor] WorldViewModel.load annotations: \(summary)")
        #endif
    }

    func bubblesForCurrentScope() -> [WorldMapBubble] {
        let base = mapScope == .global ? Self.globalBubbles : Self.localBubbles
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.displayName.lowercased().contains(q) }
    }

    func worldAverageLine() -> (avg: String, delta: String) {
        let scores = Self.globalBubbles.map(\.averageScore)
        guard !scores.isEmpty else { return ("—", "") }
        let avg = Double(scores.reduce(0, +)) / Double(scores.count)
        return (String(format: "%.1f", avg / 10.0), "+0.2")
    }

    func nationalAverageLabel(for countryId: String) -> String {
        guard let bubble = bubble(for: countryId) else { return "—" }
        return String(format: "%.1f", Double(bubble.averageScore) / 10.0)
    }

    func feedTitle(for countryId: String) -> String {
        let name = bubble(for: countryId)?.displayName ?? countryId
        return "\(name) FEED"
    }

    func regionDisplayName(for countryId: String) -> String {
        bubble(for: countryId)?.displayName ?? countryId
    }

    func feedEntries(for countryId: String) -> [CountryFeedUserEntry] {
        Self.feedData[countryId] ?? Self.genericRegionalFeed
    }

    /// Resolves from both scopes so pushed country detail stays correct if map scope changes.
    private func bubble(for countryId: String) -> WorldMapBubble? {
        Self.globalBubbles.first { $0.id == countryId }
            ?? Self.localBubbles.first { $0.id == countryId }
    }

    private func bubblesForScope(_ scope: WorldMapScope) -> [WorldMapBubble] {
        scope == .global ? Self.globalBubbles : Self.localBubbles
    }

    private static let genericRegionalFeed: [CountryFeedUserEntry] = [
        CountryFeedUserEntry(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            displayName: "Explorer",
            timeLabel: "1h ago",
            reason: "Checking in from this region.",
            score: 80,
            avatarURL: nil,
            likeCount: 4,
            liked: false
        ),
    ]

    /// Per-country sample feeds; keys must match `WorldMapBubble.id` for that scope.
    private static let feedData: [String: [CountryFeedUserEntry]] = [
        "KOREA": [
            CountryFeedUserEntry(
                id: UUID(uuidString: "A0000000-0000-4000-8000-000000000001")!,
                displayName: "Kim Min-su",
                timeLabel: "2m ago",
                reason: "Finally finished the marathon!",
                score: 92,
                avatarURL: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuCNhDsr8xM60zY0jrDhEgFdEiT8Bb_LD6pcbFe7WZf-_A3BJbzSGqW2t6TnRndzYYCp4Qln6WBpwrqctz54aW6oolkjcG_8i_yvG71MoJUfO7FSsdcvQR5YQPLbd3ZuJ_gV_QO54TyXmSdETr_NIT2rP8jkQEd8lQKMcm9psFmbuSFPFNW72ps-uwcLFcCsedx6kf4-5qyRCfxPIFpSjTvK83N0Ml0f49jTpA74eKDW_NOEe2-vW_feDngQPGIbMNuAYu2la_0MQOdG"),
                likeCount: 24,
                liked: true
            ),
            CountryFeedUserEntry(
                id: UUID(uuidString: "A0000000-0000-4000-8000-000000000002")!,
                displayName: "Park J.",
                timeLabel: "15m ago",
                reason: "The weather in Seoul is absolutely perfect today.",
                score: 88,
                avatarURL: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuD1ICnFJXNa-E_SAh8ccmRonmBT3qrLe0yFp-obVMoi1xbRJ7xuhPHU5zdKqAYzp1cq6weD8apCfGoKZWzWaocW3yirubZATZh7kV_E64uFIGbo_XDb7OmnG0vsDRXJD7fY_l2rvn5ESfMtTpCkg5Id8QsypPhh5jF2ITFCom2JPwQIOvSuZGivze2GYvMdRrbz-q9M0WIHMmXlhM_XpD32aNKHUYGHqLrHaq3g-yd1NAr5fPRIPnSfEU29LNk0pMT0zIkKIm7Q2UPG"),
                likeCount: 12,
                liked: false
            ),
            CountryFeedUserEntry(
                id: UUID(uuidString: "A0000000-0000-4000-8000-000000000003")!,
                displayName: "Lee Sang-ho",
                timeLabel: "42m ago",
                reason: "Got a surprise promotion at work! Still in shock.",
                score: 96,
                avatarURL: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuA13YAdG5BMwMla0hYDKUGj_Xsb5YBOsq7iro4v3z5kk4nO1jf3OIHfK1EkwKql6G6rZSQ3Jx8NPPpHEg9vMbEup_eIfXvzaCmbVTr_NKKZtJ-ucN2fDTCVK_zZivdVZAb7vWSQOuNl6uN7V6KpIeuvbSthMJazGoiBdipJnWZNZ6SBs7icpvPEQuwl_Ua0mrLhe6gyC5huK5mUdy1UT-2IBRqZsU-crVO75kuSYgi4ryPxDAhB6k4BwVhqLXYWJBp-xSQX6ittax_u"),
                likeCount: 56,
                liked: true
            ),
            CountryFeedUserEntry(
                id: UUID(uuidString: "A0000000-0000-4000-8000-000000000004")!,
                displayName: "Ji-won",
                timeLabel: "1h ago",
                reason: "Delicious lunch with my old college roommates.",
                score: 82,
                avatarURL: URL(string: "https://lh3.googleusercontent.com/aida-public/AB6AXuCQhrQ0FaAqePr4VtWTD7BzspqnBnK6aax9003FQRUXB7wOwmafmWvs2t4IyBn0DBwJObGiXgoCXGoTRma0Q8Faick3NZuNqsaK92Xcswcitn7U_kC6OQv4kweGb4B_mZWY4NlUqX-OX8e5HZdYUOS7tWa6AefzUobtxQoYcpmdtw4n_sA0bksCZmOuiygrVnL95V2yJTuY7IbyR92j5GRNnOOzGlQFQorgzK2kF4_nVBecGpl1DwQQ7xjs4OopPt5_6fM3sazX82ZR"),
                likeCount: 8,
                liked: false
            ),
        ],
        "USA": genericRegionalFeed,
        "UK": genericRegionalFeed,
        "BRAZIL": genericRegionalFeed,
        "AUS": genericRegionalFeed,
        "NG": genericRegionalFeed,
        "SEOUL": genericRegionalFeed,
        "BUSAN": genericRegionalFeed,
        "DAEGU": genericRegionalFeed,
    ]
}
