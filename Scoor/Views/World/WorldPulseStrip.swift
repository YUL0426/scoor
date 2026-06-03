//
//  WorldPulseStrip.swift
//  Scoor
//
//  World 탭 상단의 “WORLD PULSE” 컴팩트 티커.
//  - 토픽 레벨 통계 (비트코인 ↑, 코스피 ↓, 대선 토론회 hottest …)를 한 줄에 흘림.
//  - 32pt 높이만 차지. 시네마틱 카드 아님.
//

import SwiftUI

struct WorldPulseStrip: View {

    let pulses: [WorldPulse]
    @State private var ping = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                liveIndicator
                ForEach(pulses) { pulse in
                    pulsePill(pulse)
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 32)
        .onAppear { ping = true }
    }

    private var liveIndicator: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(ScoorPalette.accent.opacity(0.35))
                    .frame(width: ping ? 14 : 6, height: ping ? 14 : 6)
                    .opacity(ping ? 0 : 0.9)
                Circle()
                    .fill(ScoorPalette.accent)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 14, height: 14)
            .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: ping)

            Text("WORLD PULSE")
                .font(ScoorType.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(ScoorPalette.accent)
        }
        .padding(.trailing, 4)
    }

    private func pulsePill(_ pulse: WorldPulse) -> some View {
        HStack(spacing: 6) {
            Image(systemName: pulse.glyph)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint(for: pulse.kind))
            Text(pulse.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.04))
        )
        .overlay(
            Capsule().stroke(ScoorPalette.hairlineSoft, lineWidth: 0.5)
        )
    }

    private func tint(for kind: WorldPulse.Kind) -> Color {
        switch kind {
        case .rising, .hottest, .fresh: return ScoorPalette.accent
        case .falling:                  return ScoorPalette.night
        case .mostEmotional, .mostPosts: return ScoorPalette.inkSecondary
        }
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        WorldPulseStrip(pulses: MockWorld.pulses)
    }
    .environment(\.colorScheme, .dark)
}
