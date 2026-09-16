//
//  ReactionBarView.swift
//  Scoor
//
//  피드 액션 바.
//  - 좋아요 · 댓글 · 리포스트 (서버 연결 시)
//  - 카운트는 SF Symbols 옆에 작은 모노 숫자
//  - heart는 토글 시 채워지고 살짝 펄스, 햅틱
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ReactionBarView: View {

    let entryId: UUID
    @Binding var reactions: PostReactions
    var onCommentTap: () -> Void = {}
    /// 좋아요 토글 직후 호출(영속용). 인자는 토글 후의 "좋아요됨" 상태.
    var onLikeToggle: (Bool) -> Void = { _ in }

    var onRepostTap: (() -> Void)? = nil
    var repostPending = false

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

            if let onRepostTap {
                actionItem(symbol: "arrow.2.squarepath",
                           tint: reactions.repostedByMe ? ScoorPalette.accent : ScoorPalette.inkSecondary,
                           count: reactions.reposts, action: onRepostTap)
                    .disabled(repostPending)
                    .accessibilityLabel(reactions.repostedByMe ? "리포스트 취소" : "리포스트")
                    .accessibilityIdentifier("feed-repost-\(entryId)")
                    .accessibilityAddTraits(reactions.repostedByMe ? .isSelected : [])
            }

            Spacer(minLength: 0)
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
        onLikeToggle(reactions.likedByMe)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.18)) { heartBump = false }
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
