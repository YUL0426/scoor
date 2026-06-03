//
//  FirstScoorPromptView.swift
//  Scoor
//
//  Onboarding 직후 곧바로 등장하는 ‘첫 점수’ 입력 화면.
//  - 디테일은 추후 ScoreHomeView로 위임하되, 첫 인상은 매우 가볍게.
//  - 슬라이더 + 점수 표시 + 한 줄 입력 + 제출 / 건너뛰기.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FirstScoorPromptView: View {

    var onSubmit: (Int, String?) async -> Void
    var onSkip: () -> Void

    @State private var score: Double = 50
    @State private var note: String = ""
    @State private var isSubmitting = false
    @FocusState private var noteFocused: Bool

    private var intScore: Int { Int(score.rounded()) }
    private var tone: ScoreTone { .from(score: intScore) }
    private var displayColor: Color {
        tone == .soft ? DesignTokens.textPrimary : tone.primary
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.94, blue: 0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                Spacer()

                VStack(spacing: 18) {
                    Text("How was your day today?")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(DesignTokens.textPrimary)

                    Text("Slide to your score. Trust the first feeling.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.48))
                }

                Spacer()

                scoreDisplay
                    .padding(.bottom, 12)

                slider
                    .padding(.horizontal, 28)

                Spacer().frame(height: 28)

                noteField
                    .padding(.horizontal, 22)

                Spacer()

                actionRow
                    .padding(.horizontal, 22)
                    .padding(.bottom, 28)
            }
        }
        .onTapGesture { noteFocused = false }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text("FIRST SCOOR")
                .font(.system(size: 10.5, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(ScoorPalette.accent)
            Spacer()
            Button("Skip") { onSkip() }
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.38))
        }
    }

    // MARK: - Big score display

    private var scoreDisplay: some View {
        ZStack {
            // 점수 톤에 따라 옅게 빛나는 후광
            Circle()
                .fill(displayColor.opacity(0.18))
                .frame(width: 220, height: 220)
                .blur(radius: 40)

            Text("\(intScore)")
                .font(.system(size: 132, weight: .black, design: .rounded))
                .tracking(-6)
                .foregroundStyle(displayColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: intScore)
        }
        .frame(height: 180)
    }

    // MARK: - Slider

    private var slider: some View {
        VStack(spacing: 6) {
            Slider(value: $score, in: 0...100, step: 1) { editing in
                if !editing { haptic() }
            }
            .tint(displayColor)

            HStack {
                Text("0").font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("50").font(.system(size: 10, weight: .semibold))
                Spacer()
                Text("100").font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Color.black.opacity(0.38))
        }
    }

    // MARK: - One-line note

    private var noteField: some View {
        HStack(spacing: 10) {
            TextField(
                "",
                text: $note,
                prompt: Text("Add one tiny note (optional)")
                    .foregroundStyle(Color.black.opacity(0.34))
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(DesignTokens.textPrimary)
            .focused($noteFocused)
            .submitLabel(.done)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(noteFocused ? ScoorPalette.accent.opacity(0.55)
                                    : Color.black.opacity(0.08),
                        lineWidth: 1)
        )
    }

    // MARK: - Action row

    private var actionRow: some View {
        OnboardingButton(title: isSubmitting ? "Saving..." : "Save my first Scoor",
                         style: .primary, isEnabled: !isSubmitting) {
            Task { await submit() }
        }
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        await onSubmit(intScore, trimmed.isEmpty ? nil : trimmed)
        isSubmitting = false
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    FirstScoorPromptView(onSubmit: { _, _ in }, onSkip: {})
}
