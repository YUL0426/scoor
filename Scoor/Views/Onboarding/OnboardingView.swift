//
//  OnboardingView.swift
//  Scoor
//
//  Two quick intro pages before the first-score interaction.
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let pages: [TourPage] = [
        .init(
            message: "Record your day using a score.",
            caption: "No diary pressure. Just one number that remembers how today felt.",
            kind: .score
        ),
        .init(
            message: "See how people around the world felt today.",
            caption: "A live emotional pulse from real days, cities, and tiny moments.",
            kind: .world
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.95, blue: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    OnboardingPageIndicator(pageCount: pages.count, currentIndex: page)
                    Spacer()
                    Button("Skip") { onComplete() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.38))
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        TourPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                OnboardingButton(
                    title: page == pages.count - 1 ? "Try your first Scoor" : "Next",
                    style: .primary,
                    action: advance
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        // Light onboarding canvas: pin scheme so adaptive text renders dark-on-light
        // regardless of the device appearance (BUG-003).
        .environment(\.colorScheme, .light)
    }

    private func advance() {
        if page < pages.count - 1 {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                page += 1
            }
        } else {
            onComplete()
        }
    }
}

private struct TourPage: Identifiable {
    enum Kind {
        case score
        case world
    }

    let id = UUID()
    let message: String
    let caption: String
    let kind: Kind
}

private struct TourPageView: View {
    let page: TourPage

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 22)

            preview
                .padding(.horizontal, 28)

            VStack(spacing: 12) {
                Text(page.message)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(page.caption)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.50))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 30)
            }

            Spacer(minLength: 10)
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch page.kind {
        case .score:
            ScoreIntroCard()
        case .world:
            WorldIntroCard()
        }
    }
}

private struct ScoreIntroCard: View {
    @State private var score = 84

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.3)
                    .foregroundStyle(Color.black.opacity(0.36))
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
            }

            Text("\(score)")
                .font(.system(size: 118, weight: .black, design: .rounded))
                .foregroundStyle(DesignTokens.primaryColor)
                .monospacedDigit()
                .contentTransition(.numericText())

            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(Color.black.opacity(0.08))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(DesignTokens.primaryColor)
                            .frame(width: 220)
                    }

                Text("soft, quick, honest")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
        }
        .padding(22)
        .frame(height: 310)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: DesignTokens.primaryColor.opacity(0.14), radius: 28, x: 0, y: 16)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                score = 86
            }
        }
    }
}

private struct WorldIntroCard: View {
    private let rows = [
        ("Seoul", "today was lighter", 82),
        ("Paris", "quiet morning, better night", 64),
        ("New York", "too much, still moving", 41)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DesignTokens.primaryColor)
                Text("WORLD PULSE")
                    .font(.system(size: 11, weight: .black))
                    .tracking(1.3)
                    .foregroundStyle(Color.black.opacity(0.38))
                Spacer()
                Text("LIVE")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(DesignTokens.primaryColor)
                    .clipShape(Capsule())
            }

            ForEach(rows, id: \.0) { city, text, score in
                HStack(spacing: 12) {
                    Text("\(score)")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(score > 70 ? DesignTokens.primaryColor : DesignTokens.textPrimary)
                        .monospacedDigit()
                        .frame(width: 48, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(city)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(text)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.black.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(14)
                .background(Color.white.opacity(0.76))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(18)
        .frame(height: 310)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 26, x: 0, y: 16)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
