//
//  FirstScoorSuccessView.swift
//  Scoor
//
//  첫 감정 제출 직후의 ‘몰입 완료’ 화면.
//  - 큰 점수 위에 펄스 링 — “당신의 감정이 세계로 퍼져나간다”는 시각 은유.
//  - 2.6초 후 자동으로 메인 앱 진입, 또는 탭으로 즉시 진입.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct FirstScoorSuccessView: View {

    let submittedScore: Int
    var onContinue: () -> Void

    @State private var reveal = false
    @State private var sub   = false
    @State private var fired = false

    private var tone: ScoreTone { .from(score: submittedScore) }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            // 풀스크린 옅은 후광
            RadialGradient(colors: [tone.primary.opacity(0.18), .clear],
                           center: .center, startRadius: 0, endRadius: 340)
                .ignoresSafeArea()

            // 펄스 링 — 점수에 매핑된 톤으로
            ZStack {
                PulseRing(color: tone.primary, size: 360, ringCount: 4, duration: 3.4)
                PulseRing(color: ScoorPalette.accent, size: 220, ringCount: 2, duration: 4.6)
            }

            VStack(spacing: 22) {
                Spacer()

                Text("\(submittedScore)")
                    .font(.system(size: 132, weight: .black, design: .rounded))
                    .tracking(-6)
                    .foregroundStyle(tone.primary)
                    .monospacedDigit()
                    .opacity(reveal ? 1 : 0)
                    .scaleEffect(reveal ? 1.0 : 0.92)
                    .shadow(color: tone.primary.opacity(0.55), radius: 20)

                VStack(spacing: 6) {
                    Text("Your emotion is now")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                    Text("part of the world.")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                }
                .opacity(sub ? 1 : 0)
                .padding(.top, 8)

                Text("당신의 한 점수가 세계의 맥박에 더해졌어요.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .opacity(sub ? 1 : 0)

                Spacer()
                Spacer()

                Text("탭해서 계속")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .opacity(sub ? 0.8 : 0)
                    .padding(.bottom, 40)
            }
        }
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .onTapGesture { fire() }
        .onAppear {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { reveal = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.7)) { sub = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { fire() }
        }
    }

    private func fire() {
        guard !fired else { return }
        fired = true
        onContinue()
    }
}

#Preview {
    FirstScoorSuccessView(submittedScore: 82, onContinue: {})
}
