//
//  PulseRing.swift
//  Scoor
//
//  Onboarding/완료/감정 제출 등에서 반복되는 ‘세계의 맥박’ 모티브.
//  - 동심원이 천천히 퍼지며 사라짐
//  - 작게 쓰면 작은 emotional cue, 크게 쓰면 hero
//

import SwiftUI

struct PulseRing: View {
    var color: Color
    var size: CGFloat = 240
    var ringCount: Int = 3
    var duration: Double = 3.4

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(0.40 - Double(i) * 0.10), lineWidth: 1)
                    .frame(width: size, height: size)
                    .scaleEffect(animate ? 1.55 : 0.42)
                    .opacity(animate ? 0 : 0.95)
                    .animation(
                        .easeOut(duration: duration)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * (duration / Double(ringCount))),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PulseRing(color: .red, size: 260)
    }
}
