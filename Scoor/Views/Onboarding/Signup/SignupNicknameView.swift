//
//  SignupNicknameView.swift
//  Scoor
//
//  Username creation with real-time mock availability and auto-suggestions.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct SignupNicknameView: View {
    var onContinue: (String, String?) -> Void

    @State private var name = ""
    @State private var avatarIndex = 0
    @State private var availability: UsernameAvailability = .idle
    @FocusState private var focused: Bool

    private let avatars = ["84", "72", "99", "31", "56", "08", "91", "47"]
    private let fallbackSuggestions = ["todaywas84", "nightwalker", "scoorer92"]

    private var normalizedName: String {
        name
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            .prefix(20)
            .description
    }

    private var canContinue: Bool {
        if case .available = availability { return true }
        return false
    }

    private var suggestions: [String] {
        let base = normalizedName.isEmpty ? "scoorer" : normalizedName
        let seed = abs(base.hashValue % 90) + 10
        let candidates = [
            "\(base)\(seed)",
            "todaywas\(max(seed, 84))",
            "scoorer\(seed)",
            "nightwalker",
            "scoorer92"
        ]
        var seen: Set<String> = []
        return candidates.filter { seen.insert($0).inserted }.prefix(5).map { $0 }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.95, blue: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                VStack(spacing: 12) {
                    Text("Choose your Scoor name")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This is how people find your daily scores.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.48))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer().frame(height: 30)

                avatarPicker

                Spacer().frame(height: 28)

                usernameField
                    .padding(.horizontal, 24)

                suggestionRow
                    .padding(.top, 16)

                Spacer()

                OnboardingButton(
                    title: "Claim @\(normalizedName.isEmpty ? "scoor" : normalizedName)",
                    style: .primary,
                    isEnabled: canContinue
                ) {
                    let avatar = avatars[avatarIndex]
                    onContinue(normalizedName, avatar)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .onTapGesture { focused = false }
        .onChange(of: name) { _, newValue in
            let cleaned = newValue
                .lowercased()
                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
            if cleaned != newValue {
                name = String(cleaned.prefix(20))
            }
        }
        .task(id: normalizedName) {
            await validateUsername(normalizedName)
        }
    }

    private var avatarPicker: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                avatarIndex = (avatarIndex + 1) % avatars.count
            }
            haptic(.light)
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignTokens.primaryColor, Color(red: 1.0, green: 0.48, blue: 0.40)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                    .shadow(color: DesignTokens.primaryColor.opacity(0.28), radius: 24, x: 0, y: 14)

                Text(avatars[avatarIndex])
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .id(avatarIndex)
                    .transition(.opacity.combined(with: .scale(scale: 0.84)))
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color.black.opacity(0.82))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Choose profile image")
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                Text("@")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.32))

                TextField("todaywas84", text: $name)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(DesignTokens.textPrimary)
                    .focused($focused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)

                availabilityIcon
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(fieldStrokeColor, lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 10)

            Text(availability.message)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(availability.messageColor)
                .padding(.leading, 6)
                .animation(.easeInOut(duration: 0.18), value: availability)
        }
    }

    @ViewBuilder
    private var availabilityIcon: some View {
        switch availability {
        case .checking:
            ProgressView()
                .tint(DesignTokens.primaryColor)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.green)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(DesignTokens.primaryColor)
        case .idle:
            EmptyView()
        }
    }

    private var fieldStrokeColor: Color {
        switch availability {
        case .available:
            return Color.green.opacity(0.5)
        case .taken, .invalid:
            return DesignTokens.primaryColor.opacity(0.58)
        case .checking:
            return DesignTokens.primaryColor.opacity(0.38)
        case .idle:
            return Color.black.opacity(0.08)
        }
    }

    private var suggestionRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Suggestions")
                .font(.system(size: 11, weight: .black))
                .tracking(1.1)
                .foregroundStyle(Color.black.opacity(0.36))
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                name = suggestion
                                focused = false
                            }
                            haptic(.light)
                        } label: {
                            Text("@\(suggestion)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(DesignTokens.textPrimary)
                                .padding(.vertical, 9)
                                .padding(.horizontal, 13)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.black.opacity(0.07), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    @MainActor
    private func validateUsername(_ value: String) async {
        guard !value.isEmpty else {
            availability = .idle
            return
        }
        guard value.count >= 3 else {
            availability = .invalid("Use at least 3 characters.")
            return
        }

        availability = .checking
        try? await Task.sleep(nanoseconds: 360_000_000)
        guard value == normalizedName else { return }

        availability = MockUsernameAPI.isAvailable(value) ? .available : .taken
        if case .available = availability {
            haptic(.soft)
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

private enum UsernameAvailability: Equatable {
    case idle
    case checking
    case available
    case taken
    case invalid(String)

    var message: String {
        switch self {
        case .idle:
            return "Letters, numbers, and underscores only."
        case .checking:
            return "Checking availability..."
        case .available:
            return "Looks good. It is yours."
        case .taken:
            return "That name is already taken."
        case .invalid(let reason):
            return reason
        }
    }

    var messageColor: Color {
        switch self {
        case .available:
            return .green
        case .taken, .invalid:
            return DesignTokens.primaryColor
        case .idle, .checking:
            return Color.black.opacity(0.42)
        }
    }
}

private enum MockUsernameAPI {
    private static let takenNames: Set<String> = [
        "scoor",
        "admin",
        "todaywas84",
        "nightwalker",
        "scoorer92",
        "instagram",
        "threads"
    ]

    static func isAvailable(_ username: String) -> Bool {
        !takenNames.contains(username)
    }
}

#Preview {
    SignupNicknameView { _, _ in }
}
