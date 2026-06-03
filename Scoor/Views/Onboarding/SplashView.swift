//
//  SplashView.swift
//  Scoor
//
//  새 다크 스플래시.
//  - 검정 베이스, 빨간 ●LIVE 점, “Scoor” wordmark.
//  - 1.6초 후 자동 진행.
//  - Threads 진입처럼 가볍고 짧음.
//

import SwiftUI

struct SplashView: View {
    var onComplete: () -> Void

    @State private var revealText: Double = 0
    @State private var pulseAnim = false

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            // 화면 전체에 멀리서 비치는 옅은 후광 — 매우 약하게
            RadialGradient(colors: [ScoorPalette.accent.opacity(0.16), .clear],
                           center: .center, startRadius: 0, endRadius: 260)
                .ignoresSafeArea()
                .blendMode(.plusLighter)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(ScoorPalette.accent.opacity(0.35))
                        .frame(width: pulseAnim ? 26 : 10, height: pulseAnim ? 26 : 10)
                        .opacity(pulseAnim ? 0 : 0.9)
                    Circle()
                        .fill(ScoorPalette.accent)
                        .frame(width: 10, height: 10)
                }
                .animation(
                    .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                    value: pulseAnim
                )

                ScoorLogo(size: 46, variant: .white)
                    .opacity(revealText)

                Text("See how the world feels today.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .opacity(revealText)
            }
            .padding(.bottom, 16)
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            pulseAnim = true
            withAnimation(.easeOut(duration: 0.8)) { revealText = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onComplete() }
        }
    }
}

#Preview { SplashView(onComplete: {}) }
