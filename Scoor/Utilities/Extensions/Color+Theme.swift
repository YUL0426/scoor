//
//  Color+Theme.swift
//  Scoor
//
//  Design tokens extracted from Stitch design files.
//

import SwiftUI

extension Color {
    // Primary — official Scoor brand red, sampled from the finalized logo.
    static let scoorRed = Color(hex: "CE3B22")
    static let scoorRedLight = Color(hex: "FBECE8")

    // Backgrounds
    static let scoorBackground = Color(hex: "F8F5F5")
    static let scoorLightGray = Color(hex: "F4F4F5")

    // Text & UI (scoorDarkText, scoorGray are on ShapeStyle below to avoid redeclaration and support .foregroundStyle(.scoorGray))

    // Gradients (for backgrounds and cards)
    static let scoorGradientStart = Color(hex: "FFF5F5")
    static let scoorGradientEnd = Color(hex: "F8F5F5")
    static let scoorCardGradientStart = Color.white
    static let scoorCardGradientEnd = Color(hex: "FAFAFA")
}

extension ShapeStyle where Self == Color {
    /// Theme colors for use with `.foregroundStyle()` and as `Color.scoorDarkText` / `Color.scoorGray`
    static var scoorDarkText: Color { Color(hex: "18181B") }
    static var scoorGray: Color { Color(hex: "9CA3AF") }
}

extension Color {
    // Initialization from hex
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let r, g, b: UInt64
        (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
