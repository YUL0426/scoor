//
//  SignupLoginOptionsView.swift
//  Scoor
//
//  Minimal auth handler. Email creates/verifies a real device-local account via
//  AuthService (salted PBKDF2 credential in the Keychain); Apple/Google delegate
//  to the real provider sign-in upstream.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct SignupLoginOptionsView: View {
    var onAuthenticated: (AuthProvider, String?) -> Void

    @EnvironmentObject private var authService: AuthService

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    private var canContinue: Bool {
        email.contains("@") && email.contains(".") && password.count >= 6 && !isLoading
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color(red: 1.0, green: 0.94, blue: 0.94)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 62)

                VStack(spacing: 8) {
                    Text("Create your account")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(DesignTokens.textPrimary)
                    Text("Just enough to save your days.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.48))
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 34)

                VStack(spacing: 12) {
                    authField(
                        title: "Email",
                        placeholder: "you@scoor.app",
                        text: $email,
                        field: .email,
                        keyboard: .emailAddress,
                        isSecure: false
                    )

                    authField(
                        title: "Password",
                        placeholder: "6+ characters",
                        text: $password,
                        field: .password,
                        keyboard: .default,
                        isSecure: true
                    )

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Button {
                        Task { await submitEmail() }
                    } label: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            Text(isLoading ? "Creating..." : "Continue")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(DesignTokens.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .opacity(canContinue ? 1 : 0.45)
                    }
                    .buttonStyle(AuthPressStyle())
                    .disabled(!canContinue)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 10) {
                    Text("or keep it instant")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.42))

                    HStack(spacing: 10) {
                        compactSocialButton("Apple", systemImage: "apple.logo") {
                            authenticateSocial(.apple)
                        }
                        compactSocialButton("Google", systemImage: "g.circle.fill") {
                            authenticateSocial(.google)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .environment(\.colorScheme, .light) // Light canvas — keep text dark-on-light (BUG-003)
        .onTapGesture { focusedField = nil }
    }

    private func authField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType,
        isSecure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.48))

            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(DesignTokens.textPrimary)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .focused($focusedField, equals: field)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        focusedField == field ? DesignTokens.primaryColor.opacity(0.62) : Color.black.opacity(0.07),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 8)
        }
    }

    private func compactSocialButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(DesignTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(AuthPressStyle())
    }

    @MainActor
    private func submitEmail() async {
        guard canContinue else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let identity = try await authService.signInWithEmail(email: email, password: password)
            onAuthenticated(.email, identity.email)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func authenticateSocial(_ provider: AuthProvider) {
        errorMessage = nil
        onAuthenticated(provider, nil)
    }
}

private struct AuthPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

#Preview {
    SignupLoginOptionsView { _, _ in }
        .environmentObject(AuthService())
}
