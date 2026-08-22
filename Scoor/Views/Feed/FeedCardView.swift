//
//  FeedCardView.swift
//  Scoor
//
//  Toss Community/Threads 톤의 컴팩트 피드 카드.
//  - 카드 박스/후광 없음. 플랫 row + 하단 hairline divider.
//  - 한 줄 본문이 시각적 중심. 점수는 우상단 작은 배지로 항상 보이지만 본문보다 작음.
//  - 액션 2종: heart · comment (BUG-005: repost / clap 제거).
//

import SwiftUI

struct FeedCardView: View {

    @Binding var entry: FeedEntry
    var onLikeToggle: (Bool) -> Void = { _ in }
    var onCommentTap: () -> Void = {}
    /// nil이면 더보기 메뉴 자체를 감춘다 — 신고를 받을 백엔드가 없는 빌드에서
    /// 아무 데도 가지 않는 메뉴를 보여주지 않기 위해서다.
    var onReportTap: (() -> Void)? = nil

    private var tone: ScoreTone { .from(score: entry.score) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 8) {
                metaRow
                bodyText
                if hasTagsOrWeather { tagsRow }
                ReactionBarView(
                    entryId: entry.id,
                    reactions: Binding(
                        get: { entry.reactions },
                        set: { entry.reactions = $0 }
                    ),
                    onCommentTap: onCommentTap,
                    onLikeToggle: onLikeToggle
                )
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Score-first: 점수를 우측에 크게 고정 — 스크롤 중에도 즉시 읽힌다.
            VStack(alignment: .trailing, spacing: 6) {
                scoreColumn
                if let onReportTap { moreMenu(onReportTap) }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - More menu (App Store Guideline 1.2 — UGC는 어디서든 신고 가능해야 한다)

    private func moreMenu(_ onReport: @escaping () -> Void) -> some View {
        Menu {
            Button("신고하기", systemImage: "flag", role: .destructive, action: onReport)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ScoorPalette.inkTertiary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("더보기")
        .accessibilityIdentifier("feed.card.moreButton")
    }

    // MARK: - Score column (우측 고정 · 카드의 1차 시각 요소)

    private var scoreColumn: some View {
        ScoreValueView(
            score: entry.score,
            font: .system(size: 40, weight: .heavy, design: .rounded),
            color: tone.primary,
            italic: true,
            logoHeight: 28,
            logoVariant: .white
        )
        .shadow(color: tone.primary.opacity(0.28), radius: 10)
        .frame(minWidth: 54, alignment: .trailing)
        .padding(.top, 1)
        .accessibilityLabel("Scoor 점수 \(entry.score)")
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
        if entry.identity.isAnonymous { return "?" }
        let n = entry.identity.name
        return String(n.prefix(1)).uppercased()
    }

    /// 닉네임 seed → 9가지 채도 낮은 색 중 하나.
    private var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.43, green: 0.49, blue: 0.66),  // dusty blue
            Color(red: 0.66, green: 0.45, blue: 0.51),  // dusty rose
            Color(red: 0.51, green: 0.57, blue: 0.50),  // sage
            Color(red: 0.71, green: 0.55, blue: 0.39),  // tan
            Color(red: 0.50, green: 0.47, blue: 0.63),  // muted violet
            Color(red: 0.42, green: 0.55, blue: 0.55),  // teal-gray
            Color(red: 0.62, green: 0.58, blue: 0.42),  // olive
            Color(red: 0.58, green: 0.49, blue: 0.55),  // muted mauve
            Color(red: 0.45, green: 0.52, blue: 0.59)   // slate
        ]
        let idx = max(0, min(palette.count - 1, entry.identity.avatarSeed - 1))
        return palette[idx]
    }

    // MARK: - Meta row (이름 · 도시 · 시간 …………………… 점수)

    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(displayName)
                .font(ScoorType.name)
                .foregroundStyle(ScoorPalette.inkPrimary)
                .lineLimit(1)

            // 운영자가 등록한 글임을 이름 옆에서 바로 밝힌다. 이게 없으면 공식
            // 글이 일반 사용자 글과 구분되지 않아, 배너를 떼자마자 예전의
            // "가짜 소셜 데이터"(P0-1) 문제로 되돌아간다.
            if entry.isOfficial {
                Text("공식")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ScoorPalette.bgBase)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(ScoorPalette.accent, in: Capsule())
                    .accessibilityLabel("Scoor 공식 글")
            }

            if !entry.city.isEmpty || !entry.countryFlag.isEmpty {
                dot
                Text(entry.countryFlag)
                    .font(.system(size: 11))
                Text(entry.city)
                    .font(ScoorType.meta)
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .lineLimit(1)
            }

            dot
            Text(RelativeTime.short(from: entry.postedAt))
                .font(ScoorType.meta)
                .foregroundStyle(ScoorPalette.inkTertiary)
                .monospacedDigit()

            Spacer(minLength: 4)
        }
    }

    private var displayName: String {
        entry.identity.isAnonymous ? String(localized: "익명") : entry.identity.name
    }

    private var dot: some View {
        Text("·")
            .font(ScoorType.meta)
            .foregroundStyle(ScoorPalette.inkTertiary)
    }

    // MARK: - Body

    private var bodyText: some View {
        Text(entry.message)
            .font(ScoorType.body)
            .foregroundStyle(ScoorPalette.inkPrimary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Tags + weather

    private var hasTagsOrWeather: Bool {
        !entry.extraTags.isEmpty || entry.weather != nil
            || entry.primaryMood != .calm // primaryMood도 하나는 노출
    }

    private var tagsRow: some View {
        HStack(spacing: 6) {
            tagPill(entry.primaryMood.hashtag, isPrimary: true)
            ForEach(entry.extraTags.prefix(2), id: \.self) { mood in
                tagPill(mood.hashtag, isPrimary: false)
            }
            if let w = entry.weather {
                Text(w.glyph).font(.system(size: 11))
            }
            Spacer()
        }
    }

    private func tagPill(_ text: String, isPrimary: Bool) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(
                isPrimary ? ScoorPalette.inkPrimary.opacity(0.85)
                          : ScoorPalette.inkSecondary
            )
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(
                Capsule().fill(
                    isPrimary ? Color.white.opacity(0.07)
                              : Color.white.opacity(0.04)
                )
            )
    }
}

#Preview {
    struct Wrap: View {
        @State var entries = MockFeed.entries
        var body: some View {
            ZStack {
                ScoorPalette.bgBase.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries.indices, id: \.self) { i in
                            FeedCardView(entry: $entries[i])
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
