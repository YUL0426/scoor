//
//  DesignTokens.swift
//  Scoor
//
//  Unified design tokens: colors, spacing, corner radius, shadow.
//

import SwiftUI

enum DesignTokens {
    // MARK: - Colors (Option A: Full Dark Default)
    static var primaryColor: Color { Color.scoorRed }
    static var backgroundColor: Color { Color(hex: "0A0A0B") }
    static var cardBackground: Color { Color(hex: "141417") }
    static var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "141417"), Color(hex: "1A1A1E")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "0A0A0B"), Color(hex: "0D0D0F")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    static var textPrimary: Color { Color(hex: "F5F5F8") }
    static var textSecondary: Color { Color(hex: "7B7B85") }
    static var surfaceLight: Color { Color(hex: "1E1E22") }
    static var surfaceElevated: Color { Color(hex: "252529") }
    static var hairline: Color { Color.white.opacity(0.07) }

    // MARK: - Corner Radius
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusCard: CGFloat = 20
    static let cornerRadiusCardLarge: CGFloat = 24

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 16
    static let spacingXL: CGFloat = 20
    static let spacingXXL: CGFloat = 24
    static let spacingXXXL: CGFloat = 28

    // MARK: - Shadow
    static let shadowRadiusCard: CGFloat = 12
    static let shadowYCard: CGFloat = 4
    static let shadowOpacityCard: Double = 0.06
    static let shadowRadiusCardLarge: CGFloat = 16
    static let shadowYCardLarge: CGFloat = 6

    // MARK: - Animation (HIG: subtle, purposeful)
    static let animationSpringResponse: Double = 0.35
    static let animationSpringDamping: Double = 0.82
    static let animationTabTransitionDuration: Double = 0.25
    static let animationScoreBumpScale: CGFloat = 1.04
    static let animationCardPressScale: CGFloat = 0.98
}
