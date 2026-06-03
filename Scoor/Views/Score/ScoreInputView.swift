//
//  ScoreInputView.swift
//  Scoor
//
//  Score tab: centered brand, background, date — no score entry UI on this screen.
//

import SwiftUI

struct ScoreInputView: View {
    private let scoreService: ScoreServiceProtocol
    private let userService: UserServiceProtocol

    init(scoreService: ScoreServiceProtocol, userService: UserServiceProtocol) {
        self.scoreService = scoreService
        self.userService = userService
    }

    var body: some View {
        ZStack {
            flowBackground

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    dateBlock

                    ScoorLogo(size: 44, variant: .red)
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 0)
            }
        }
        .overlay {
            Color.clear
                .accessibilityHidden(true)
                .onAppear {
                    _ = scoreService
                    _ = userService
                }
        }
    }

    private var flowBackground: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            Circle()
                .fill(DesignTokens.primaryColor.opacity(0.05))
                .frame(width: 500, height: 500)
                .blur(radius: 100)
                .offset(x: 160, y: -320)
                .allowsHitTesting(false)
            Circle()
                .fill(DesignTokens.primaryColor.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -140, y: 340)
                .allowsHitTesting(false)
        }
    }

    private var dateBlock: some View {
        VStack(spacing: 4) {
            Text("How was your day?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color(red: 0.45, green: 0.51, blue: 0.57))
            Text(formattedDateLine)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(red: 0.58, green: 0.64, blue: 0.69))
                .tracking(3)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var formattedDateLine: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: Date()).uppercased()
    }
}

#Preview("Score home") {
    ScoreInputView(scoreService: MockScoreService(), userService: MockUserService())
}
