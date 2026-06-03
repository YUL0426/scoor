//
//  Typography.swift
//  Scoor
//
//  Unified typography: score large, title, subtitle, body.
//

import SwiftUI

enum AppTypography {
    // MARK: - Score
    /// Very large score number (e.g. main score display)
    static func scoreLarge(size: CGFloat = 120) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    // MARK: - Titles
    /// Screen or section title
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    /// Section header (e.g. "Daily scores")
    static func sectionTitle() -> Font {
        .system(size: 18, weight: .bold)
    }
    /// Smaller section or card title
    static func subtitle() -> Font {
        .system(size: 15, weight: .semibold)
    }
    static func subtitleMedium() -> Font {
        .system(size: 16, weight: .medium)
    }

    // MARK: - Body
    static func body() -> Font {
        .system(size: 16, weight: .regular)
    }
    static func bodySmall() -> Font {
        .system(size: 14, weight: .regular)
    }
    static func caption() -> Font {
        .system(size: 12, weight: .medium)
    }
    static func captionBold() -> Font {
        .system(size: 11, weight: .semibold)
    }
}
