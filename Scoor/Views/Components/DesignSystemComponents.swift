//
//  DesignSystemComponents.swift
//  Scoor
//
//  Reusable UI: AppCard, SectionHeader, ScoreDisplay, UserScoreRow, AppButton.
//

import SwiftUI

// MARK: - AppCard

struct AppCard<Content: View>: View {
    var useGradient: Bool = false
    var padding: CGFloat = DesignTokens.spacingXL
    var cornerRadius: CGFloat = DesignTokens.cornerRadiusCard
    var useLargeShadow: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Rectangle().fill(
                    useGradient
                        ? AnyShapeStyle(DesignTokens.cardBackgroundGradient)
                        : AnyShapeStyle(DesignTokens.cardBackground)
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: .black.opacity(DesignTokens.shadowOpacityCard),
                radius: useLargeShadow ? DesignTokens.shadowRadiusCardLarge : DesignTokens.shadowRadiusCard,
                x: 0,
                y: useLargeShadow ? DesignTokens.shadowYCardLarge : DesignTokens.shadowYCard
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(useGradient ? Color.white.opacity(0.8) : .clear, lineWidth: 1)
            )
    }
}

// MARK: - Card Press Button Style (elevation on tap)

struct CardPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DesignTokens.animationCardPressScale : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - SectionHeader

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var paddingHorizontal: CGFloat = DesignTokens.spacingXXL

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text(title)
                .font(AppTypography.sectionTitle())
                .foregroundStyle(DesignTokens.textPrimary)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(AppTypography.bodySmall())
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, paddingHorizontal)
    }
}

// MARK: - ScoreDisplay

struct ScoreDisplay: View {
    let score: Int
    var size: CGFloat = 120
    var useGradient: Bool = true

    private var foregroundStyle: AnyShapeStyle {
        if useGradient {
            AnyShapeStyle(LinearGradient(
                colors: [DesignTokens.primaryColor, DesignTokens.primaryColor.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(DesignTokens.primaryColor)
        }
    }

    var body: some View {
        Text("\(score)")
            .font(AppTypography.scoreLarge(size: size))
            .foregroundStyle(foregroundStyle)
            .contentTransition(.numericText())
    }
}

// MARK: - UserScoreRow

struct UserScoreRow: View {
    let title: String
    let subtitle: String?
    let score: Int
    var initial: String? = nil
    var showAvatar: Bool = true

    private var displayInitial: String {
        initial ?? String(title.prefix(1)).uppercased()
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.spacingMD) {
            if showAvatar {
                Circle()
                    .fill(DesignTokens.primaryColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(displayInitial)
                            .font(AppTypography.sectionTitle())
                            .foregroundStyle(DesignTokens.primaryColor)
                    )
            }

            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTypography.bodySmall())
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }

            Spacer()

            Text("\(score)")
                .font(AppTypography.scoreLarge(size: 28))
                .foregroundStyle(DesignTokens.primaryColor)
        }
    }
}

// MARK: - AppButton

struct AppButton: View {
    let title: String
    var icon: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                    }
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(isEnabled ? DesignTokens.primaryColor : DesignTokens.textSecondary)
                    .shadow(color: DesignTokens.primaryColor.opacity(isEnabled ? 0.4 : 0), radius: 12, x: 0, y: 6)
            )
            .overlay(
                Capsule()
                    .stroke(DesignTokens.primaryColor.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!isEnabled || isLoading)
    }
}
