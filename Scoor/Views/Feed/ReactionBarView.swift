//
//  ReactionBarView.swift
//  Scoor
//
//  Toss Community/Threads 스타일의 4-액션 바.
//  - heart · comment · repost · empathy
//  - 카운트는 SF Symbols 옆에 작은 모노 숫자
//  - heart는 토글 시 채워지고 살짝 펄스, 햅틱
//  - empathy는 길게 누르면 4종 글리프 picker
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ReactionBarView: View {

    let entryId: UUID
    @Binding var reactions: PostReactions
    var onCommentTap: () -> Void = {}
    var onRepostTap: () -> Void = {}

    @State private var showEmpathyPicker = false
    @State private var heartBump = false

    var body: some View {
        HStack(spacing: 0) {
            actionItem(
                symbol: reactions.likedByMe ? "heart.fill" : "heart",
                tint: reactions.likedByMe ? ScoorPalette.accent : ScoorPalette.inkSecondary,
                count: reactions.likes,
                bump: heartBump,
                action: toggleLike
            )

            actionItem(symbol: "bubble.right",
                       tint: ScoorPalette.inkSecondary,
                       count: reactions.comments,
                       action: onCommentTap)

            actionItem(symbol: "arrow.2.squarepath",
                       tint: ScoorPalette.inkSecondary,
                       count: reactions.reposts,
                       action: onRepostTap)

            empathyItem
        }
        .overlay(alignment: .bottom) {
            if showEmpathyPicker {
                empathyPicker
                    .offset(y: 44)
                    .transition(.scale(scale: 0.85, anchor: .bottom)
                        .combined(with: .opacity))
            }
        }
    }

    // MARK: - 일반 액션 아이템

    private func actionItem(symbol: String,
                            tint: Color,
                            count: Int,
                            bump: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(tint)
                    .scaleEffect(bump ? 1.18 : 1.0)
                Text(CompactCount.format(count))
                    .font(ScoorType.actionCount)
                    .foregroundStyle(tint == ScoorPalette.accent
                                     ? ScoorPalette.accent
                                     : ScoorPalette.inkTertiary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empathy

    private var empathyItem: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showEmpathyPicker.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                if let mine = reactions.empathyByMe {
                    Text(mine.glyph).font(.system(size: 15))
                } else {
                    Image(systemName: "hands.sparkles")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
                Text(CompactCount.format(reactions.empathyTotal))
                    .font(ScoorType.actionCount)
                    .foregroundStyle(
                        reactions.empathyByMe != nil
                        ? ScoorPalette.inkPrimary
                        : ScoorPalette.inkTertiary
                    )
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var empathyPicker: some View {
        HStack(spacing: 10) {
            ForEach(EmpathyReaction.allCases) { reaction in
                Button {
                    pickEmpathy(reaction)
                } label: {
                    Text(reaction.glyph)
                        .font(.system(size: 22))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(
                                reactions.empathyByMe == reaction
                                ? Color.white.opacity(0.10)
                                : Color.clear
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ScoorPalette.bgFloat)
                .overlay(Capsule().stroke(ScoorPalette.hairline, lineWidth: 0.6))
                .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 6)
        )
    }

    // MARK: - 인터랙션

    private func toggleLike() {
        haptic()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            heartBump = true
        }
        if reactions.likedByMe {
            reactions.likedByMe = false
            reactions.likes = max(0, reactions.likes - 1)
        } else {
            reactions.likedByMe = true
            reactions.likes += 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.18)) { heartBump = false }
        }
    }

    private func pickEmpathy(_ reaction: EmpathyReaction) {
        haptic()
        if reactions.empathyByMe == reaction {
            reactions.empathyByMe = nil
            reactions.empathyTotal = max(0, reactions.empathyTotal - 1)
        } else {
            if reactions.empathyByMe == nil { reactions.empathyTotal += 1 }
            reactions.empathyByMe = reaction
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showEmpathyPicker = false
        }
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    struct Wrap: View {
        @State var r = PostReactions(likes: 312, comments: 41, reposts: 8,
                                     empathyTotal: 188, likedByMe: false,
                                     empathyByMe: .hug)
        var body: some View {
            ZStack {
                ScoorPalette.bgBase.ignoresSafeArea()
                ReactionBarView(entryId: UUID(), reactions: $r)
                    .padding()
            }
        }
    }
    return Wrap()
}
