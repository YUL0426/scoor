//
//  WorldPostCardView.swift
//  Scoor
//
//  World 피드의 단일 카드 — 토픽에 매긴 개인 반응.
//  - 한 줄 본문 + 개인 점수 + 토픽 라인(글로벌 점수 ↑/↓)
//  - 카드 박스 없음. 플랫 row + hairline divider.
//  - 액션 2종: heart · comment (Feed와 동일 컴포넌트 재사용; BUG-005)
//

import SwiftUI

struct WorldPostCardView: View {

    @Binding var post: WorldPost
    var onTopicTap: () -> Void = {}
    var onLikeToggle: (Bool) -> Void = { _ in }
    var onCommentTap: () -> Void = {}

    private var tone: ScoreTone { .from(score: post.myScore) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 8) {
                identityRow
                topicRow
                bodyText
                ReactionBarView(
                    entryId: post.id,
                    reactions: Binding(
                        get: { post.reactions },
                        set: { post.reactions = $0 }
                    ),
                    onCommentTap: onCommentTap,
                    onLikeToggle: onLikeToggle
                )
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score-first: 내 점수를 우측에 크게 고정(Feed와 동일 디자인 언어).
            scoreColumn
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var scoreColumn: some View {
        ScoreValueView(
            score: post.myScore,
            font: .system(size: 40, weight: .heavy, design: .rounded),
            color: tone.primary,
            italic: true,
            logoHeight: 28,
            logoVariant: .white
        )
        .shadow(color: tone.primary.opacity(0.28), radius: 10)
        .frame(minWidth: 54, alignment: .trailing)
        .padding(.top, 1)
        .accessibilityLabel("내 Scoor \(post.myScore)")
    }

    // MARK: - Avatar

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(avatarColor)
                .frame(width: 38, height: 38)
            Text(initials)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    private var initials: String {
        post.identity.isAnonymous ? "?" : String(post.identity.name.prefix(1)).uppercased()
    }

    private var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.43, green: 0.49, blue: 0.66),
            Color(red: 0.66, green: 0.45, blue: 0.51),
            Color(red: 0.51, green: 0.57, blue: 0.50),
            Color(red: 0.71, green: 0.55, blue: 0.39),
            Color(red: 0.50, green: 0.47, blue: 0.63),
            Color(red: 0.42, green: 0.55, blue: 0.55),
            Color(red: 0.62, green: 0.58, blue: 0.42),
            Color(red: 0.58, green: 0.49, blue: 0.55),
            Color(red: 0.45, green: 0.52, blue: 0.59)
        ]
        let idx = max(0, min(palette.count - 1, post.identity.avatarSeed - 1))
        return palette[idx]
    }

    // MARK: - Identity row (이름 · 시간 ………… 내 점수)

    private var identityRow: some View {
        HStack(spacing: 6) {
            Text(displayName)
                .font(ScoorType.name)
                .foregroundStyle(ScoorPalette.inkPrimary)
                .lineLimit(1)

            Text("·")
                .font(ScoorType.meta)
                .foregroundStyle(ScoorPalette.inkTertiary)

            Text(RelativeTime.short(from: post.postedAt))
                .font(ScoorType.meta)
                .foregroundStyle(ScoorPalette.inkTertiary)
                .monospacedDigit()

            Spacer(minLength: 4)
        }
    }

    private var displayName: String {
        post.identity.isAnonymous ? String(localized: "익명") : post.identity.name
    }

    // MARK: - Topic row (카테고리 · 토픽 이름 · 글로벌 ↑)

    private var topicRow: some View {
        Button(action: onTopicTap) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text(post.topic.category.emoji).font(.system(size: 11))
                    Text(post.topic.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.88))
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                )

                HStack(spacing: 3) {
                    Text("글로벌")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                    Text("\(post.topic.globalScore)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(globalScoreColor)
                        .monospacedDigit()
                    deltaArrow
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var globalScoreColor: Color {
        ScoreTone.from(score: post.topic.globalScore).primary
    }

    private var deltaArrow: some View {
        let d = post.topic.scoreDelta
        let symbol = d > 0 ? "arrow.up" : (d < 0 ? "arrow.down" : "minus")
        let color: Color = d > 0 ? ScoorPalette.accent
                          : (d < 0 ? ScoorPalette.night : ScoorPalette.inkTertiary)
        return Image(systemName: symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
    }

    // MARK: - Body

    private var bodyText: some View {
        Text(post.message)
            .font(ScoorType.body)
            .foregroundStyle(ScoorPalette.inkPrimary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    struct Wrap: View {
        @State var posts = MockWorld.posts
        var body: some View {
            ZStack {
                ScoorPalette.bgBase.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(posts.indices, id: \.self) { i in
                            WorldPostCardView(post: $posts[i])
                            Divider().background(ScoorPalette.hairline)
                        }
                    }
                }
            }
            .environment(\.colorScheme, .dark)
        }
    }
    return Wrap()
}
