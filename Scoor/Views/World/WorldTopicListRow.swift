//
//  WorldTopicListRow.swift
//  Scoor
//
//  서버 토픽 목록의 한 행.
//
//  토픽이 실데이터로 바뀐 뒤 World 탭의 본문은 시드 글 스트림이 아니라 이 목록이
//  된다 — 사용자가 실제로 할 수 있는 행동(토픽에 점수 매기기)으로 바로 이어지는
//  유일한 표면이기 때문이다.
//

import SwiftUI

struct WorldTopicListRow: View {

    let topic: WorldTopic
    var onSelect: () -> Void = {}

    private var tone: ScoreTone { .from(score: topic.globalScore) }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Text(topic.emoji)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(ScoorPalette.bgRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(topic.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(topic.category.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                        // 아직 아무도 점수를 안 매긴 토픽이 대부분인 구간이다.
                        // "0명"이라고 쓰는 대신 참여를 권한다.
                        Text(topic.postsCount == 0
                             ? String(localized: "첫 점수를 남겨보세요")
                             : String(localized: "\(topic.postsCount)명 참여"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                    }
                }

                Spacer(minLength: 8)

                if topic.postsCount > 0 {
                    Text("\(topic.globalScore)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(tone.primary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
