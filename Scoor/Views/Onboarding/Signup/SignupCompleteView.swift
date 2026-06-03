//
//  SignupCompleteView.swift
//  Scoor
//
//  가입 4단계 — “Welcome, Scoorer.” 임팩트 화면.
//  - PulseRing 두 겹 + 큰 카피
//  - 2.6초 후 자동 진행, 또는 탭으로 즉시 다음 단계
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct SignupCompleteView: View {

    let name: String
    let avatarEmoji: String?
    var onContinue: () -> Void

    @State private var reveal = false
    @State private var subReveal = false
    @State private var autoAdvanceFired = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ScoorPalette.bgBase,
                    Color(red: 0.25, green: 0.02, blue: 0.06),
                    DesignTokens.primaryColor.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 배경 후광
            RadialGradient(colors: [ScoorPalette.accent.opacity(0.16), .clear],
                           center: .center, startRadius: 0, endRadius: 320)
                .ignoresSafeArea()

            // PulseRings
            ZStack {
                PulseRing(color: ScoorPalette.accent, size: 360, ringCount: 3, duration: 4.0)
                PulseRing(color: ScoorPalette.inkSecondary, size: 200, ringCount: 2, duration: 5.5)
            }

            VStack(spacing: 16) {
                avatarRow
                    .padding(.top, 100)

                Spacer()

                VStack(spacing: 10) {
                    Text("Welcome, Scoorer!")
                        .font(.system(size: 46, weight: .black, design: .rounded))
                        .tracking(-1.6)
                        .foregroundStyle(ScoorPalette.inkPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(reveal ? 1 : 0)
                        .offset(y: reveal ? 0 : 10)
                }

                Text("Now start recording your days.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.76))
                    .lineSpacing(4)
                    .padding(.top, 14)
                    .opacity(subReveal ? 1 : 0)

                Spacer()

                Text("탭해서 계속")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .padding(.bottom, 40)
                    .opacity(subReveal ? 0.8 : 0)
            }
        }
        .environment(\.colorScheme, .dark)
        .contentShape(Rectangle())
        .onTapGesture { fire() }
        .onAppear {
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { reveal = true }
            withAnimation(.easeOut(duration: 0.8).delay(0.9)) { subReveal = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { fire() }
        }
    }

    private func fire() {
        guard !autoAdvanceFired else { return }
        autoAdvanceFired = true
        onContinue()
    }

    private var avatarRow: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ScoorPalette.bgRaised)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(ScoorPalette.hairline, lineWidth: 0.8))
                Text(avatarEmoji ?? "✨").font(.system(size: 22))
            }
            Text("@\(name.isEmpty ? "scoorer" : name)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ScoorPalette.inkPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            Capsule().fill(ScoorPalette.bgRaised.opacity(0.6))
        )
        .overlay(
            Capsule().stroke(ScoorPalette.hairline, lineWidth: 0.5)
        )
        .opacity(reveal ? 1 : 0)
    }
}

#Preview {
    SignupCompleteView(name: "nightowl", avatarEmoji: "🌙") {}
}
