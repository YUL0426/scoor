//
//  LivePulseView.swift
//  Scoor
//
//  컴팩트 LIVE PULSE 티커.
//  - 기존 시네마틱 카드를 폐기. 한 줄짜리 horizontal scroll pill strip으로 대체.
//  - 좌측에 호흡하는 ●LIVE 인디케이터, 우측으로 짧은 펄스 pill들이 흐른다.
//  - 화면 면적을 거의 안 쓰고 “지금 사람들 분위기”만 빠르게 전달.
//

import SwiftUI

struct LivePulseView: View {

    let pulses: [LivePulse]
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

    // MARK: - Live indicator

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
            .animation(
                .easeOut(duration: 1.6).repeatForever(autoreverses: false),
                value: ping
            )

            Text("LIVE")
                .font(ScoorType.sectionLabel)
                .tracking(1.2)
                .foregroundStyle(ScoorPalette.accent)
        }
        .padding(.trailing, 4)
    }

    // MARK: - Pulse pill

    private func pulsePill(_ pulse: LivePulse) -> some View {
        HStack(spacing: 6) {
            Image(systemName: pulse.glyph)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text(pulse.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.86))
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
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        LivePulseView(pulses: MockFeed.pulses)
    }
    .environment(\.colorScheme, .dark)
}
