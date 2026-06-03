//
//  SharedComponents.swift
//  Scoor
//
//  Reusable UI components used across multiple screens.
//

import SwiftUI

// MARK: - Scoor Logo (official wordmark)

/// The official Scoor wordmark, rendered from the finalized brand asset.
/// Use `.red` on light surfaces and `.white` on dark surfaces for strong contrast.
struct ScoorLogo: View {
    enum Variant { case red, white }

    /// Rendered height of the wordmark in points. The width scales to the
    /// logo's native aspect ratio (≈1.65:1) — never set width directly.
    var size: CGFloat = 24
    var variant: Variant = .red

    private var assetName: String {
        switch variant {
        case .red:   return "ScoorWordmark"
        case .white: return "ScoorWordmarkWhite"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(height: size)
            .accessibilityLabel("Scoor")
    }
}

// MARK: - Icon Circle Button

struct IconCircleButton: View {
    let icon: String
    var tint: Color = .primary
    var background: Color = DesignTokens.surfaceLight
    var size: CGFloat = 36

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: size * 0.44))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(background)
                .clipShape(Circle())
        }
    }
}

// MARK: - Triangle Shape

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var positions: [CGPoint] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (
            size: CGSize(width: maxWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        ScoorLogo()
        ScoorLogo(size: 48)

        HStack {
            IconCircleButton(icon: "chart.bar.fill", tint: DesignTokens.primaryColor, background: DesignTokens.primaryColor.opacity(0.1))
            IconCircleButton(icon: "person.fill")
            IconCircleButton(icon: "gearshape.fill")
        }
    }
    .padding()
}
