//
//  ScoreValueView.swift
//  Scoor
//
//  점수 렌더링의 단일 진입점. 브랜드 규칙: 점수가 100이면 "100" 숫자 대신
//  Scoor 로고 트리트먼트를 노출한다(로고 안에 "100" 컨셉이 들어 있음).
//
//  - 모든 점수 표기는 이 컴포넌트(또는 이를 사용하는 FeedScoreDisplay)를 거친다.
//  - 폰트/색/이탤릭/로고 높이를 호출부에서 주입해 기존 타이포를 그대로 유지.
//

import SwiftUI

/// 점수 하나를 표기. `score >= 100`이면 숫자 대신 `ScoorLogo`로 자동 치환.
struct ScoreValueView: View {
    let score: Int
    /// 숫자 폰트. 기본은 피드 배지(18pt).
    var font: Font = ScoorType.scoreBadge(18)
    /// 숫자 색. nil이면 점수 톤(`ScoreTone`)의 primary 색.
    var color: Color? = nil
    /// 숫자에 이탤릭 적용 여부(대형 감정 숫자용).
    var italic: Bool = false
    /// monospacedDigit 적용 여부.
    var monospaced: Bool = true
    /// 100일 때 표시할 로고 높이. 기본은 폰트 캡 높이에 가깝게.
    var logoHeight: CGFloat = 18
    /// 로고 변형(어두운 배경엔 .white 권장).
    var logoVariant: ScoorLogo.Variant = .red

    private var resolvedColor: Color { color ?? ScoreTone.from(score: score).primary }

    /// 100점 규칙 적용 여부(호출부 레이아웃 분기에 활용).
    static func isLogoScore(_ score: Int) -> Bool { score >= 100 }

    var body: some View {
        if Self.isLogoScore(score) {
            ScoorLogo(size: logoHeight, variant: logoVariant)
                .accessibilityLabel("Scoor 만점 100")
        } else {
            numberText
                .monospacedDigit(enabled: monospaced)
                .foregroundStyle(resolvedColor)
                .accessibilityLabel("Scoor 점수 \(score)")
        }
    }

    @ViewBuilder
    private var numberText: some View {
        let base = Text("\(score)").font(font)
        if italic { base.italic() } else { base }
    }
}

// 가독성을 위한 조건부 monospacedDigit 헬퍼.
private extension View {
    @ViewBuilder
    func monospacedDigit(enabled: Bool) -> some View {
        if enabled { self.monospacedDigit() } else { self }
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        VStack(spacing: 20) {
            ScoreValueView(score: 92)
            ScoreValueView(score: 100, logoHeight: 18)                 // → 로고
            ScoreValueView(score: 100,
                           font: .system(size: 96, weight: .heavy, design: .rounded),
                           italic: true,
                           logoHeight: 64,
                           logoVariant: .white)                        // → 큰 로고
            ScoreValueView(score: 73,
                           font: .system(size: 96, weight: .heavy, design: .rounded),
                           italic: true)
        }
    }
    .environment(\.colorScheme, .dark)
}
