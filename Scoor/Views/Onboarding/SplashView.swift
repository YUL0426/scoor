//
//  SplashView.swift
//  Scoor
//
//  A short greeting reveal followed by the Scoor wordmark.
//

import SwiftUI

struct SplashView: View {
    var onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var greetingProgress: CGFloat = 0
    @State private var showLogo = false

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("How's your day?")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .mask(alignment: .leading) {
                        GeometryReader { geometry in
                            Rectangle()
                                .frame(width: (geometry.size.width + 24) * greetingProgress)
                                .blur(radius: greetingProgress == 1 ? 0 : 6)
                        }
                    }
                    .accessibilityLabel("How's your day?")
                    .accessibilityIdentifier("splash-greeting")

                ScoorLogo(size: 88, variant: .white)
                    .opacity(showLogo ? 1 : 0)
                    .offset(y: showLogo || reduceMotion ? 0 : 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .environment(\.colorScheme, .dark)
        .task {
            greetingProgress = 0
            showLogo = false
            do {
                if reduceMotion {
                    greetingProgress = 1
                    showLogo = true
                    try await Task.sleep(for: .seconds(1.6))
                } else {
                    try await Task.sleep(for: .milliseconds(150))
                    withAnimation(.easeInOut(duration: 0.95)) {
                        greetingProgress = 1
                    }
                    try await Task.sleep(for: .milliseconds(1000))
                    withAnimation(.easeOut(duration: 0.35)) {
                        showLogo = true
                    }
                    try await Task.sleep(for: .milliseconds(850))
                }
                try Task.checkCancellation()
                onComplete()
            } catch {
                // Leaving the splash cancels its pending transition.
            }
        }
    }
}

#Preview { SplashView(onComplete: {}) }
