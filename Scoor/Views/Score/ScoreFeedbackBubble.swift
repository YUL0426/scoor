//
//  ScoreFeedbackBubble.swift
//  Scoor
//

import SwiftUI

struct ScoreFeedbackBubble: View {
    let message: String
    let type: FeedbackType
    var onDismiss: (() -> Void)?

    @State private var isVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Text(message)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.spacingLG)
                .padding(.vertical, DesignTokens.spacingMD)
                .frame(maxWidth: .infinity)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                        .stroke(borderColor, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .onTapGesture { dismiss() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                dismiss()
            }
        }
    }

    private var borderColor: Color {
        switch type {
        case .positive: return Color(hex: "22C55E")
        case .neutral: return DesignTokens.textSecondary
        case .encouragement: return Color(hex: "F97316")
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .positive: return Color(hex: "22C55E").opacity(0.08)
        case .neutral: return DesignTokens.surfaceLight.opacity(0.8)
        case .encouragement: return Color(hex: "F97316").opacity(0.08)
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss?()
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ScoreFeedbackBubble(message: "23 points higher than last week!", type: .positive)
        ScoreFeedbackBubble(message: "Score recorded! Keep tracking. 📝", type: .neutral)
    }
    .padding()
}
