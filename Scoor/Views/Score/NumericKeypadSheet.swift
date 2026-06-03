//
//  NumericKeypadSheet.swift
//  Scoor
//
//  Design ref: design/1. score/daily_score_input_2
//

import SwiftUI

struct NumericKeypadSheet: View {
    @Binding var score: Int
    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""
    @State private var cursorBlinkPhase = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { applyAndDismiss() }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignTokens.primaryColor)
                }
                .padding(.trailing, 8)
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(red: 0.45, green: 0.48, blue: 0.52))
                        .padding(12)
                        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text("DAILY SCORE")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color(red: 0.64, green: 0.64, blue: 0.68))
                    .tracking(3)

                HStack(alignment: .center, spacing: 8) {
                    Text(displayScore)
                        .font(.system(size: 96, weight: .heavy))
                        .foregroundStyle(DesignTokens.primaryColor)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(DesignTokens.primaryColor.opacity(0.3))
                        .frame(width: 6, height: 88)
                        .opacity(cursorBlinkPhase ? 1 : 0.3)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: cursorBlinkPhase)
                }

                Text("What's the number for today?")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(red: 0.64, green: 0.64, blue: 0.68))
                    .italic()
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(1...9, id: \.self) { n in
                    keypadDigit(String(n))
                }
                keypadAux("Clear", isClear: true)
                keypadDigit("0")
                keypadCheck
            }
            .padding(16)
            .background(Color(red: 0.97, green: 0.98, blue: 0.99))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 40,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 40,
                    style: .continuous
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: 40,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 40,
                    style: .continuous
                )
                .stroke(Color(red: 0.94, green: 0.95, blue: 0.96), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 20, x: 0, y: -10)
        }
        .background(Color.white)
        .presentationDetents([.large])
        .onAppear {
            inputText = "\(score)"
            if score == 0 { inputText = "" }
            cursorBlinkPhase = true
        }
    }

    private var displayScore: String {
        inputText.isEmpty ? "0" : inputText
    }

    private func keypadDigit(_ s: String) -> some View {
        Button {
            appendDigit(s)
        } label: {
            Text(s)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadCellButtonStyle())
    }

    private func keypadAux(_ title: String, isClear: Bool) -> some View {
        Button {
            if isClear { inputText = "" }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color(red: 0.55, green: 0.58, blue: 0.62))
                .tracking(2)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .contentShape(Rectangle())
        }
        .buttonStyle(KeypadCellButtonStyle())
    }

    private var keypadCheck: some View {
        Button {
            applyAndDismiss()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(DesignTokens.primaryColor)
                .clipShape(Circle())
                .shadow(color: DesignTokens.primaryColor.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private func appendDigit(_ s: String) {
        let next = inputText + s
        guard next.count <= 3, let v = Int(next), v <= 100 else { return }
        inputText = next
    }

    private func applyAndDismiss() {
        let value = Int(inputText) ?? 0
        score = min(100, max(0, value))
        dismiss()
    }
}

private struct KeypadCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? DesignTokens.primaryColor.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    NumericKeypadSheet(score: .constant(82))
}
