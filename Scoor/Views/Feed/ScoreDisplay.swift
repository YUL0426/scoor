//
//  ScoreDisplay.swift
//  Scoor
//
//  Feed 카드 우상단에 들어가는 컴팩트 점수 배지.
//  - 메인 프로젝트의 ScoreDisplay와 충돌 회피하기 위해 `FeedScoreDisplay`로 명명.
//  - 시네마틱 호흡·후광 제거. 텍스트 우선 카드에 맞게 작고 또렷하게.
//

import SwiftUI

/// 단일 점수를 표시하는 컴팩트 배지. 기본 크기 22pt.
struct FeedScoreDisplay: View {
    let score: Int
    /// 숫자 폰트 사이즈. 헤더용 22pt가 기본.
    var size: CGFloat = 22
    /// 배경 pill 표시 여부. false면 숫자만.
    var withChip: Bool = false

    private var tone: ScoreTone { .from(score: score) }

    var body: some View {
        // 점수 100 → 로고 치환은 ScoreValueView가 일괄 처리.
        ScoreValueView(
            score: score,
            font: ScoorType.scoreBadge(size),
            color: tone.primary,
            logoHeight: size * 0.92
        )
        .padding(.horizontal, withChip ? 10 : 0)
        .padding(.vertical,   withChip ? 4  : 0)
        .background(
            Group {
                if withChip {
                    Capsule().fill(tone.chipBackground)
                }
            }
        )
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        VStack(spacing: 16) {
            FeedScoreDisplay(score: 92)
            FeedScoreDisplay(score: 78)
            FeedScoreDisplay(score: 54)
            FeedScoreDisplay(score: 34)
            FeedScoreDisplay(score: 18, withChip: true)
            FeedScoreDisplay(score: 91, size: 28, withChip: true)
        }
    }
}
