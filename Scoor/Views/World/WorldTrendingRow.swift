//
//  WorldTrendingRow.swift
//  Scoor
//
//  “지금 뜨거운 토픽” 가로 스크롤 영역.
//  - 토픽 레벨 정보(글로벌 점수, 추세, heat, 글 수)를 빠르게 한 줄에 노출.
//  - 카드는 작고 컴팩트 — 카드 하나 = 토픽 하나.
//

import SwiftUI

struct WorldTrendingRow: View {

    let topics: [WorldTopic]
    var onSelect: (WorldTopic) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("지금 뜨거운 토픽")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                Spacer()
                Text("더 보기")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(topics.prefix(8)) { t in
                        Button { onSelect(t) } label: { TopicMiniCard(topic: t) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }
}

// MARK: - Mini card

private struct TopicMiniCard: View {

    let topic: WorldTopic

    private var tone: ScoreTone { .from(score: topic.globalScore) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category chip
            HStack(spacing: 4) {
                Text(topic.category.emoji).font(.system(size: 11))
                Text(topic.category.label.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(ScoorPalette.inkSecondary)
            }

            // Title
            Text("\(topic.emoji) \(topic.title)")
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            // Score + delta
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ScoreValueView(
                    score: topic.globalScore,
                    font: .system(size: 32, weight: .heavy, design: .rounded),
                    color: tone.primary,
                    logoHeight: 24
                )
                deltaBadge
                Spacer()
            }

            // Heat label
            Text(topic.heat.label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(heatColor)

            // Posts count footer
            HStack(spacing: 4) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                // CompactCount는 0을 빈 문자열로 낸다. 시드에서는 모든 토픽이
                // 수천 건이라 드러나지 않았지만, 실제 서비스의 새 토픽은 전부
                // 0에서 시작해 "글"만 덩그러니 남는다.
                Text(topic.postsCount > 0
                     ? "\(CompactCount.format(topic.postsCount))글"
                     : "아직 반응 없음")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
        }
        .padding(12)
        .frame(width: 160, height: 168, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(ScoorPalette.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.6)
        )
    }

    private var deltaBadge: some View {
        let isUp = topic.scoreDelta > 0
        let isFlat = topic.scoreDelta == 0
        let label = "\(isUp ? "+" : "")\(topic.scoreDelta)"
        let color: Color = isFlat ? ScoorPalette.inkTertiary
                                  : (isUp ? ScoorPalette.accent : ScoorPalette.night)
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .monospacedDigit()
    }

    private var heatColor: Color {
        switch topic.heat {
        case .hot, .rising, .fresh: return ScoorPalette.accent
        case .falling:              return ScoorPalette.night
        case .calm:                 return ScoorPalette.inkSecondary
        }
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        WorldTrendingRow(topics: MockWorld.topics)
    }
    .environment(\.colorScheme, .dark)
}
