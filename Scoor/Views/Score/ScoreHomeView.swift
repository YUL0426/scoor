//
//  ScoreHomeView.swift
//  Scoor
//
//  Score input sheet: dark canvas, large emotional number, inline keypad.
//  Initial state: empty (—). Backspace removes one digit at a time.
//

import SwiftUI

struct ScoreHomeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ScoreInputViewModel
    @State private var keypadInput: String = ""
    @FocusState private var reasonFocused: Bool
    @State private var scoreScale: CGFloat = 1.0

    init(
        scoreService: ScoreServiceProtocol,
        userService: UserServiceProtocol,
        moodAnalyzer: MoodAnalyzing = DisabledMoodAnalyzer(),
        notificationService: NotificationServiceProtocol = MockNotificationService(),
        targetDate: Date = Date()
    ) {
        _viewModel = StateObject(wrappedValue: ScoreInputViewModel(
            scoreService: scoreService,
            userService: userService,
            moodAnalyzer: moodAnalyzer,
            notificationService: notificationService,
            targetDate: targetDate
        ))
    }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header

                Spacer(minLength: 0)

                // Question + score display
                VStack(spacing: 0) {
                    Text(viewModel.isTargetToday ? "오늘 하루는 어땠나요?" : "그 날은 어땠나요?")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                        .padding(.bottom, 4)

                    Text(formattedDateLine)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                        .tracking(2)

                    // Large score
                    scoreDisplay
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                }

                // Feedback message
                if let message = viewModel.feedbackMessage {
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Inline reason field — tap to type directly (no modal).
                reasonField
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                Spacer(minLength: 12)

                // Inline keypad
                ScoorKeypadView(
                    inputText: $keypadInput,
                    onDone: { Task { await viewModel.submitScore() } },
                    doneLabel: viewModel.isSubmitting ? "···" : (viewModel.isUpdateMode ? String(localized: "업데이트") : "Scoor!"),
                    isDoneDisabled: viewModel.isSubmitting
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 32)
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await viewModel.loadTodaysScore() }
        .onAppear {
            if viewModel.score > 0 {
                keypadInput = "\(viewModel.score)"
            }
        }
        .onChange(of: viewModel.score) { _, new in
            if new > 0, keypadInput != "\(new)" {
                keypadInput = "\(new)"
            } else if new == 0 {
                keypadInput = ""
            }
        }
        .onChange(of: keypadInput) { _, new in
            let value = Int(new) ?? 0
            viewModel.updateScore(value)
            bounceScore()
        }
        .onChange(of: viewModel.isSubmitted) { _, submitted in
            if submitted {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: viewModel.feedbackMessage)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            ScoorLogo(size: 22, variant: .white)

            Spacer()

            Text(formattedDateLine)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ScoorPalette.inkTertiary)
                .tracking(1.5)

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .frame(width: 34, height: 34)
                    .background(ScoorPalette.bgRaised)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(ScoorPalette.hairline, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("닫기")
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Score display

    private var scoreDisplay: some View {
        let currentScore = Int(keypadInput) ?? 0
        let tone = ScoreTone.from(score: currentScore)

        // 점수 100은 숫자 대신 Scoor 로고로(브랜드 규칙).
        return Group {
            if currentScore >= 100 {
                ScoorLogo(size: 78, variant: .white)
            } else {
                Text(keypadInput.isEmpty ? "—" : keypadInput)
                    .font(.system(size: 108, weight: .heavy, design: .rounded))
                    .italic()
                    .foregroundStyle(keypadInput.isEmpty
                                     ? ScoorPalette.inkTertiary
                                     : tone.primary)
                    .contentTransition(.numericText(countsDown: false))
            }
        }
        .scaleEffect(scoreScale)
        .shadow(color: keypadInput.isEmpty
                ? .clear
                : tone.primary.opacity(0.35), radius: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: keypadInput)
    }

    // MARK: - Inline reason field

    /// 사유 입력은 모달/태그 없이 인라인. 탭하면 즉시 네이티브 키보드가 뜨고
    /// 바로 한 줄로 타이핑한다. 완료(Done) 시 키보드만 내려가고, 저장은 키패드의
    /// "Scoor!" 버튼이 담당해 기존 저장/수정 플로우를 그대로 유지한다.
    private var reasonField: some View {
        HStack(spacing: 10) {
            Image(systemName: viewModel.reason.isEmpty ? "pencil" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(viewModel.reason.isEmpty
                                 ? ScoorPalette.inkTertiary
                                 : DesignTokens.primaryColor)

            TextField(
                "",
                text: reasonBinding,
                prompt: Text("오늘의 감정을 한 줄로...")
                    .foregroundColor(ScoorPalette.inkTertiary)
            )
            .focused($reasonFocused)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ScoorPalette.inkPrimary)
            .tint(DesignTokens.primaryColor)
            .submitLabel(.done)
            .onSubmit { reasonFocused = false }
            .accessibilityIdentifier("reason-field")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(ScoorPalette.bgRaised)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                reasonFocused ? DesignTokens.primaryColor.opacity(0.55) : ScoorPalette.hairline,
                lineWidth: reasonFocused ? 1 : 0.5
            )
        )
    }

    // MARK: - Helpers

    private func bounceScore() {
        Task { @MainActor in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) {
                scoreScale = 1.07
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                scoreScale = 1.0
            }
        }
    }

    private var reasonBinding: Binding<String> {
        Binding(
            get: { viewModel.reason },
            set: { viewModel.setReason($0) }
        )
    }

    private var formattedDateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, MMM d"
        return f.string(from: viewModel.targetDate).uppercased()
    }
}

#Preview {
    ScoreHomeView(scoreService: MockScoreService(), userService: MockUserService())
}
