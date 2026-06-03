//
//  OnboardingPageIndicator.swift
//  Scoor
//
//  Onboarding tour 상단/하단에 들어가는 dot indicator.
//  - 활성 점은 길게 늘어남 (Threads/Linear 스타일)
//

import SwiftUI

struct OnboardingPageIndicator: View {
    let pageCount: Int
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(
                        i == currentIndex
                        ? DesignTokens.primaryColor.opacity(0.92)
                        : Color.black.opacity(0.16)
                    )
                    .frame(width: i == currentIndex ? 22 : 6, height: 4)
                    .animation(.easeInOut(duration: 0.22), value: currentIndex)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingPageIndicator(pageCount: 4, currentIndex: 1)
    }
}
