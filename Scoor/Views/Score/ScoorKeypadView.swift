//
//  ScoorKeypadView.swift
//  Scoor
//
//  Reusable dark-mode numeric keypad for score input.
//  Used by ScoreHomeView (daily score) and TopicScoreSheet (world topics).
//
//  Layout: 3×3 digit grid + bottom row [⌫] [0] [action]
//

import SwiftUI

struct ScoorKeypadView: View {
    @Binding var inputText: String
    var onDone: (() -> Void)?
    var doneLabel: String = "Scoor!"
    var isDoneDisabled: Bool = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(1...9, id: \.self) { n in
                digitButton(String(n))
            }
            backspaceButton
            digitButton("0")
            doneButton
        }
        .accessibilityIdentifier("score-keypad")
    }

    // MARK: - Digit button

    private func digitButton(_ s: String) -> some View {
        Button {
            appendDigit(s)
        } label: {
            Text(s)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScoorKeypadCellStyle())
        .accessibilityLabel(s)
        .accessibilityIdentifier("score-keypad-digit-\(s)")
    }

    // MARK: - Backspace button

    private var backspaceButton: some View {
        Button {
            guard !inputText.isEmpty else { return }
            inputText.removeLast()
            haptic()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScoorKeypadCellStyle())
        .accessibilityLabel("delete.left")
        .accessibilityIdentifier("score-keypad-delete")
    }

    // MARK: - Done/Submit button

    private var doneButton: some View {
        let canDone = onDone != nil && !isDoneDisabled && !inputText.isEmpty
        return Button {
            haptic(strong: true)
            onDone?()
        } label: {
            Text(doneLabel)
                .font(.system(size: 15, weight: .heavy))
                .italic()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canDone
                              ? DesignTokens.primaryColor
                              : DesignTokens.primaryColor.opacity(0.35))
                )
                .contentShape(Rectangle())
        }
        .disabled(!canDone)
        .buttonStyle(.plain)
        .accessibilityLabel(doneLabel)
        .accessibilityIdentifier("score-keypad-submit")
    }

    // MARK: - Helpers

    private func appendDigit(_ s: String) {
        let next = inputText + s
        guard next.count <= 3, let v = Int(next), v <= 100 else { return }
        inputText = next
        haptic()
    }

    private func haptic(strong: Bool = false) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
        #endif
    }
}

// MARK: - Button style

private struct ScoorKeypadCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed
                          ? ScoorPalette.bgRaised
                          : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    struct Wrap: View {
        @State var input = ""
        var body: some View {
            ZStack {
                ScoorPalette.bgBase.ignoresSafeArea()
                VStack(spacing: 24) {
                    Text(input.isEmpty ? "—" : input)
                        .font(.system(size: 80, weight: .heavy, design: .rounded))
                        .italic()
                        .foregroundStyle(input.isEmpty ? ScoorPalette.inkTertiary : DesignTokens.primaryColor)
                    ScoorKeypadView(inputText: $input, onDone: { print("done") }, doneLabel: "Scoor!")
                        .padding(.horizontal, 16)
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }
    return Wrap()
}
