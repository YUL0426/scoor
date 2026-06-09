//
//  ReasonInputSheet.swift
//  Scoor
//
//  Dark-mode bottom sheet for entering score reason with quick tags.
//

import SwiftUI

struct ReasonInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var reason: String
    /// Called right after the reason is committed, so the caller can auto-save the
    /// whole entry without a separate "Scoor!" tap (BUG-011).
    var onSaved: () -> Void = {}
    @State private var localText: String = ""

    init(reason: Binding<String>, onSaved: @escaping () -> Void = {}) {
        self._reason = reason
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drag handle
            Capsule()
                .fill(ScoorPalette.hairline)
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            HStack {
                Text("오늘 왜 이 점수인가요?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                        .frame(width: 32, height: 32)
                        .background(ScoorPalette.bgRaised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Text area
            ZStack(alignment: .topLeading) {
                TextEditor(text: $localText)
                    .font(.system(size: 15))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 120)
                    .padding(16)

                if localText.isEmpty {
                    Text("오늘 하루에 대해 자유롭게 써보세요...")
                        .font(.system(size: 15))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .background(ScoorPalette.bgRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ScoorPalette.hairline, lineWidth: 0.5)
            )
            .padding(.horizontal, 24)

            // Quick tags
            VStack(alignment: .leading, spacing: 10) {
                Text("빠른 태그")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .tracking(1.5)
                    .padding(.leading, 4)

                FlowLayout(spacing: 8) {
                    ForEach(["일", "가족", "건강", "취미", "친구", "운동", "날씨"], id: \.self) { tag in
                        ReasonTagChip(label: "#\(tag)") { append(tag) }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            Spacer(minLength: 0)

            // Save
            Button(action: save) {
                HStack(spacing: 8) {
                    Text("저장하기")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule()
                        .fill(localText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              ? DesignTokens.primaryColor.opacity(0.45)
                              : DesignTokens.primaryColor)
                )
                .shadow(color: DesignTokens.primaryColor.opacity(0.4), radius: 14, x: 0, y: 6)
            }
            .disabled(localText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .padding(.top, 20)
        }
        .background(ScoorPalette.bgBase)
        .environment(\.colorScheme, .dark)
        .presentationDetents([.large])
        .onAppear { localText = reason }
    }

    private func append(_ tag: String) {
        let hashTag = "#\(tag)"
        if localText.isEmpty {
            localText = "\(hashTag) "
        } else if !localText.contains(hashTag) {
            let needsSpace = !localText.hasSuffix(" ")
            localText += "\(needsSpace ? " " : "")\(hashTag) "
        }
    }

    private func save() {
        reason = localText.trimmingCharacters(in: .whitespacesAndNewlines)
        dismiss()
        // Auto-save the entry once the reason is written (BUG-011).
        onSaved()
    }
}

// MARK: - Tag Chip

struct ReasonTagChip: View {
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DesignTokens.primaryColor.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(DesignTokens.primaryColor.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReasonInputSheet(reason: .constant(""))
}
