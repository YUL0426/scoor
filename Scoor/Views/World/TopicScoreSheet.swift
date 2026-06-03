//
//  TopicScoreSheet.swift
//  Scoor
//
//  토픽 점수 입력 시트 — 키패드 방식 (Home과 동일한 인터랙션).
//  스포츠 토픽은 상단에 타겟 선택자(Match/Home/Away/MVP) 노출.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TopicScoreSheet: View {

    @Environment(\.dismiss) private var dismiss

    let topic: WorldTopic
    @Binding var target: ScoorTarget
    let existing: Int?
    var onSubmit: (Int) -> Void

    @State private var keypadInput: String = ""

    private var detail: TopicDetail { MockWorld.detail(for: topic) }
    private var tone: ScoreTone { .from(score: Int(keypadInput) ?? 0) }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if detail.sports != nil { targetSelector }

                Spacer(minLength: 0)

                bigNumber
                    .padding(.vertical, 8)

                quickPresets
                    .padding(.top, 6)

                commentFieldSection
                    .padding(.horizontal, 22)
                    .padding(.top, 16)

                Spacer(minLength: 8)

                ScoorKeypadView(
                    inputText: $keypadInput,
                    onDone: {
                        haptic(strong: true)
                        onSubmit(Int(keypadInput) ?? 0)
                        dismiss()
                    },
                    doneLabel: "Submit \(keypadInput.isEmpty ? "—" : keypadInput)",
                    isDoneDisabled: keypadInput.isEmpty
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 22)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            if let e = existing {
                keypadInput = "\(e)"
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Text(topic.emoji).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(targetSubtitle)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ScoorPalette.accent)
                Text(topic.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .lineLimit(1)
            }
            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .frame(width: 32, height: 32)
                    .background(ScoorPalette.bgRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var targetSubtitle: String {
        switch target {
        case .match: return "WHAT'S YOUR SCOOR?"
        case .team(let abbr):
            if let s = detail.sports {
                if s.home.abbr == abbr { return "SCORE · \(s.home.name.uppercased())" }
                if s.away.abbr == abbr { return "SCORE · \(s.away.name.uppercased())" }
            }
            return "SCORE · \(abbr)"
        case .mvp:
            return "SCORE · MVP \(detail.sports?.mvp?.name.uppercased() ?? "")"
        }
    }

    // MARK: - Target selector (sports only)

    private var targetSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                targetChip(.match, label: "Match", glyph: "sportscourt")
                if let s = detail.sports {
                    targetChip(.team(s.home.abbr), label: s.home.abbr, glyph: nil, leadingEmoji: s.home.crest)
                    targetChip(.team(s.away.abbr), label: s.away.abbr, glyph: nil, leadingEmoji: s.away.crest)
                    if s.mvp != nil {
                        targetChip(.mvp, label: "MVP", glyph: "star.fill")
                    }
                }
            }
            .padding(.horizontal, 22)
        }
        .padding(.bottom, 6)
    }

    private func targetChip(_ t: ScoorTarget,
                            label: String,
                            glyph: String?,
                            leadingEmoji: String? = nil) -> some View {
        let isOn = target == t
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { target = t }
        } label: {
            HStack(spacing: 5) {
                if let e = leadingEmoji { Text(e).font(.system(size: 12)) }
                if let g = glyph { Image(systemName: g).font(.system(size: 10, weight: .bold)) }
                Text(label).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isOn ? ScoorPalette.bgBase : ScoorPalette.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(isOn ? ScoorPalette.inkPrimary : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Big number display

    private var bigNumber: some View {
        VStack(spacing: 4) {
            Text(keypadInput.isEmpty ? "—" : keypadInput)
                .font(.system(size: 88, weight: .heavy, design: .rounded))
                .foregroundStyle(keypadInput.isEmpty ? ScoorPalette.inkTertiary : tone.primary)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: false))
                .animation(.spring(response: 0.18, dampingFraction: 0.8), value: keypadInput)
                .shadow(color: keypadInput.isEmpty ? .clear : tone.primary.opacity(0.4), radius: 18)

            if !keypadInput.isEmpty {
                Text(toneLabel)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(tone.primary.opacity(0.85))
            }
        }
    }

    private var toneLabel: String {
        switch tone {
        case .glow: return "PEAK"
        case .warm: return "WARM"
        case .soft: return "STEADY"
        case .dim:  return "DIM"
        case .deep: return "DEEP"
        }
    }

    // MARK: - Quick presets

    private var quickPresets: some View {
        HStack(spacing: 8) {
            preset(label: "🔥", value: 95)
            preset(label: "👍", value: 78)
            preset(label: "🙂", value: 58)
            preset(label: "😐", value: 40)
            preset(label: "💔", value: 18)
        }
        .padding(.horizontal, 22)
    }

    private func preset(label: String, value: Int) -> some View {
        let isSel = Int(keypadInput) == value
        return Button {
            haptic()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                keypadInput = "\(value)"
            }
        } label: {
            VStack(spacing: 4) {
                Text(label).font(.system(size: 18))
                Text("\(value)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSel
                        ? ScoreTone.from(score: value).primary
                        : ScoorPalette.inkTertiary)
            }
            .frame(width: 54, height: 54)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSel ? ScoreTone.from(score: value).primary.opacity(0.14)
                                : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSel
                        ? ScoreTone.from(score: value).primary.opacity(0.45)
                        : ScoorPalette.hairline, lineWidth: 0.6)
            )
        }
        .buttonStyle(PressableScaleCompact())
    }

    // MARK: - Comment field

    @State private var comment: String = ""

    private var commentFieldSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("한 줄 코멘트 · 선택")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(ScoorPalette.inkTertiary)

            TextField("이 토픽에 대한 한 줄 감정", text: $comment, axis: .vertical)
                .lineLimit(1...2)
                .font(.system(size: 14.5))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ScoorPalette.bgRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ScoorPalette.hairline, lineWidth: 0.6)
                )
        }
    }

    // MARK: - Helpers

    private func haptic(strong: Bool = false) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: strong ? .medium : .light).impactOccurred()
        #endif
    }
}

// MARK: - PressableScaleCompact button style

private struct PressableScaleCompact: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    struct Wrap: View {
        @State var t: ScoorTarget = .match
        var body: some View {
            TopicScoreSheet(
                topic: MockWorld.topics[0],
                target: $t,
                existing: nil
            ) { _ in }
        }
    }
    return Wrap()
}
