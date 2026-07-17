//
//  FirstScoorPromptView.swift
//  Scoor
//
//  Onboarding 직후 곧바로 등장하는 '첫 점수' 입력 화면.
//  - BUG-004: 실제 Scoor 입력(ScoreHomeView)과 동일한 인터랙션을 학습시키기 위해
//    슬라이더(드래그) 대신 다크 캔버스 + 큰 점수 + 인라인 숫자 키패드를 사용한다.
//  - 큰 점수 표시 + 한 줄 노트(선택) + 키패드 제출 / 건너뛰기.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FirstScoorPromptView: View {

    var onSubmit: (Int, String?) async -> Void
    var onSkip: () -> Void

    @State private var keypadInput: String = ""
    @State private var note: String = ""
    @State private var isSubmitting = false
    @FocusState private var noteFocused: Bool

    private var intScore: Int { Int(keypadInput) ?? 0 }
    private var tone: ScoreTone { .from(score: intScore) }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    Text("How was your day today?")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Text("Tap your score. Trust the first feeling.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }

                scoreDisplay
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                noteField
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                ScoorKeypadView(
                    inputText: $keypadInput,
                    onDone: { Task { await submit() } },
                    doneLabel: isSubmitting ? "···" : "Save my first Scoor",
                    isDoneDisabled: isSubmitting
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 28)
            }
        }
        .environment(\.colorScheme, .dark)
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
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
    }

    // MARK: - Big score display

    private var scoreDisplay: some View {
        Text(keypadInput.isEmpty ? "—" : keypadInput)
            .font(.system(size: 108, weight: .heavy, design: .rounded))
            .italic()
            .foregroundStyle(keypadInput.isEmpty ? ScoorPalette.inkTertiary : tone.primary)
            .contentTransition(.numericText(countsDown: false))
            .shadow(color: keypadInput.isEmpty ? .clear : tone.primary.opacity(0.35), radius: 24)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: keypadInput)
            .frame(height: 130)
    }

    // MARK: - One-line note

    private var noteField: some View {
        HStack(spacing: 10) {
            Image(systemName: note.isEmpty ? "pencil" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(note.isEmpty ? ScoorPalette.inkTertiary : DesignTokens.primaryColor)
            TextField(
                "",
                text: $note,
                prompt: Text("Add one tiny note (optional)")
                    .foregroundStyle(ScoorPalette.inkTertiary)
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ScoorPalette.inkPrimary)
            .focused($noteFocused)
            .submitLabel(.done)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 20)
        .background(ScoorPalette.bgRaised)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(ScoorPalette.hairline, lineWidth: 0.5))
    }

    // MARK: - Submit

    @MainActor
    private func submit() async {
        guard !isSubmitting, !keypadInput.isEmpty else { return }
        isSubmitting = true
        noteFocused = false
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        await onSubmit(intScore, trimmed.isEmpty ? nil : trimmed)
        isSubmitting = false
    }
}

#Preview {
    FirstScoorPromptView(onSubmit: { _, _ in }, onSkip: {})
}
