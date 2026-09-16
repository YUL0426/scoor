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
    /// 게시 단위 익명 토글. nil이면 서버 미연결 상태라 토글을 감춘다.
    /// 기본값은 닉네임 노출 — 실명은 부담스럽다는 판단으로 닉네임을 택했고(§15-2),
    /// 익명은 매 게시마다 사용자가 고르는 선택지로 남긴다.
    var isAnonymous: Binding<Bool>? = nil
    /// 제출 콜백 — (점수 0~100, 한 줄 코멘트?)
    var onSubmit: (Int, String?) -> Void

    @State private var keypadInput: String = ""
    @FocusState private var commentFocused: Bool

    private var detail: TopicDetail {
        if isAnonymous == nil { return MockWorld.detail(for: topic) }
        return TopicDetail(source: topic.category.label, summary: topic.subtitle ?? "", coverHue: 0.58,
                           globalParticipants: topic.postsCount, regional: [], sports: nil, recent: [])
    }
    private var tone: ScoreTone { .from(score: Int(keypadInput) ?? 0) }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 0) {
                        if isAnonymous != nil {
                            Text("0: \(topic.lowLabel) · 100: \(topic.highLabel)").font(.caption).foregroundStyle(ScoorPalette.accent).padding(.horizontal, 22)
                        }
                        if detail.sports != nil { targetSelector }

                        bigNumber
                            .padding(.vertical, 8)

                        commentFieldSection
                            .padding(.horizontal, 22)
                            .padding(.top, 16)

                        if let isAnonymous {
                            anonymousToggle(isAnonymous)
                                .padding(.horizontal, 22)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)

                if !commentFocused {
                    ScoorKeypadView(
                        inputText: $keypadInput,
                        onDone: {
                            haptic(strong: true)
                            let value = min(100, max(0, Int(keypadInput) ?? 0))
                            let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
                            onSubmit(value, trimmed.isEmpty ? nil : trimmed)
                            dismiss()
                        },
                        doneLabel: "Submit \(keypadInput.isEmpty ? "—" : keypadInput)",
                        isDoneDisabled: keypadInput.isEmpty
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button("완료") { commentFocused = false }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
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
        case .glow: return String(localized: "PEAK")
        case .warm: return String(localized: "WARM")
        case .soft: return String(localized: "STEADY")
        case .dim:  return String(localized: "DIM")
        case .deep: return String(localized: "DEEP")
        }
    }

    // MARK: - Comment field

    @State private var comment: String = ""

    private func anonymousToggle(_ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            HStack(spacing: 6) {
                Image(systemName: binding.wrappedValue ? "eye.slash.fill" : "person.fill")
                    .font(.system(size: 12))
                Text(binding.wrappedValue ? "익명으로 남기기" : "닉네임으로 남기기")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(ScoorPalette.inkSecondary)
        }
        .tint(ScoorPalette.inkSecondary)
    }

    private var commentFieldSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("한 줄 코멘트 · 선택")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(ScoorPalette.inkTertiary)

            TextField("이 토픽에 대한 한 줄 감정", text: $comment, axis: .vertical)
                .lineLimit(1...2)
                .focused($commentFocused)
                .accessibilityIdentifier("topic-score-comment")
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

#Preview {
    struct Wrap: View {
        @State var t: ScoorTarget = .match
        var body: some View {
            TopicScoreSheet(
                topic: MockWorld.topics[0],
                target: $t,
                existing: nil
            ) { _, _ in }
        }
    }
    return Wrap()
}
