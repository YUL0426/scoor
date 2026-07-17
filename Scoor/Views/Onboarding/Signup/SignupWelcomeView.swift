//
//  SignupWelcomeView.swift
//  Scoor
//
//  Premium auth landing: fast Instagram-style entry into Apple, Google, or email.
//

import SwiftUI

struct SignupWelcomeView: View {
    var onApple: () -> Void
    var onGoogle: () -> Void
    var onEmail: () -> Void

    @State private var reveal = false
    @State private var drift = false

    var body: some View {
        ZStack {
            emotionalBackground

            VStack(spacing: 0) {
                Spacer(minLength: 68)

                hero
                    .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 12) {
                    OnboardingButton(
                        title: "Continue with Apple",
                        style: .applePill,
                        systemImage: "apple.logo",
                        action: onApple
                    )
                    // Hidden until a Google OAuth client id is provisioned (BUG-002) —
                    // a visible button that always errors is worse than no button.
                    if GoogleSignInController.isConfigured || UITestSupport.wantsCleanState {
                        OnboardingButton(
                            title: "Continue with Google",
                            style: .googlePill,
                            systemImage: "g.circle.fill",
                            action: onGoogle
                        )
                    }
                    OnboardingButton(
                        title: "Continue with Email",
                        style: .emailPill,
                        systemImage: "envelope.fill",
                        action: onEmail
                    )

                    Text("Start in seconds. No long forms.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.58))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
                .opacity(reveal ? 1 : 0)
                .offset(y: reveal ? 0 : 20)
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.08)) {
                reveal = true
            }
            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private var emotionalBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.18, blue: 0.20),
                    Color(red: 0.36, green: 0.03, blue: 0.10),
                    ScoorPalette.bgBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.28), .clear],
                center: UnitPoint(x: drift ? 0.72 : 0.22, y: drift ? 0.22 : 0.34),
                startRadius: 0,
                endRadius: 260
            )
            .blur(radius: 18)
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color(red: 1.0, green: 0.46, blue: 0.35).opacity(0.30), .clear],
                center: UnitPoint(x: drift ? 0.24 : 0.78, y: drift ? 0.72 : 0.58),
                startRadius: 0,
                endRadius: 320
            )
            .blur(radius: 22)
            .ignoresSafeArea()

            ZStack {
                PulseRing(color: .white.opacity(0.45), size: 330, ringCount: 3, duration: 5.4)
                PulseRing(color: ScoorPalette.accent, size: 230, ringCount: 2, duration: 4.2)
            }
            .offset(y: -46)
            .opacity(0.72)
        }
    }

    private var hero: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(width: 118, height: 118)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 26, x: 0, y: 18)

                Text("84")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .scaleEffect(reveal ? 1 : 0.82)
            .opacity(reveal ? 1 : 0)

            VStack(spacing: 10) {
                ScoorLogo(size: 56, variant: .white)

                Text("How many points was your day today?")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(reveal ? 1 : 0)
            .offset(y: reveal ? 0 : 16)
        }
    }
}

#Preview {
    SignupWelcomeView(onApple: {}, onGoogle: {}, onEmail: {})
}
