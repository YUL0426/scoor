//
//  OnboardingButton.swift
//  Scoor
//
//  Onboarding 전체에서 쓰는 1차/2차 CTA 버튼.
//  - .primary: 빨간 풀 와이드 (Continue 류)
//  - .secondary: 흐릿한 텍스트 only (Skip 류)
//  - .social: 소셜 로그인 (검정/화이트 + 좌측 아이콘)
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingButton: View {
    enum Style { case primary, secondary, applePill, googlePill, emailPill, phonePill }

    let title: String
    var style: Style = .primary
    var isEnabled: Bool = true
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button {
            haptic()
            action()
        } label: {
            HStack(spacing: 8) {
                if let s = systemImage {
                    Image(systemName: s)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background)
            .overlay(border)
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(isEnabled ? 1.0 : 0.45)
        }
        .buttonStyle(PressStyle())
        .disabled(!isEnabled)
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:    ScoorPalette.accent
            case .secondary:  Color.clear
            case .applePill:  Color.white
            case .googlePill: Color.white
            case .emailPill:  Color.white.opacity(0.14)
            case .phonePill:  Color.clear
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .primary:    return .white
        case .secondary:  return ScoorPalette.inkSecondary
        case .applePill:  return .black
        case .googlePill: return .black
        case .emailPill:  return .white
        case .phonePill:  return ScoorPalette.inkPrimary
        }
    }

    @ViewBuilder
    private var border: some View {
        switch style {
        case .emailPill, .phonePill:
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        case .secondary:
            EmptyView()
        default:
            EmptyView()
        }
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 12) {
            OnboardingButton(title: "Continue", style: .primary) {}
            OnboardingButton(title: "Apple로 계속하기", style: .applePill, systemImage: "apple.logo") {}
            OnboardingButton(title: "Google로 계속하기", style: .googlePill, systemImage: "g.circle.fill") {}
            OnboardingButton(title: "전화번호로 계속하기", style: .phonePill, systemImage: "phone.fill") {}
            OnboardingButton(title: "건너뛰기", style: .secondary) {}
        }
        .padding()
    }
    .environment(\.colorScheme, .dark)
}
