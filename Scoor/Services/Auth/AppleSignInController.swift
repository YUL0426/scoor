//
//  AppleSignInController.swift
//  Scoor
//
//  Real Sign in with Apple via ASAuthorizationController, bridged to async/await.
//  Apple returns email/fullName only on the FIRST authorization for an app, so
//  callers should persist them immediately.
//

import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AppleSignInController: NSObject,
                                   ASAuthorizationControllerDelegate,
                                   ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<AuthenticatedIdentity, Error>?

    func signIn() async throws -> AuthenticatedIdentity {
        // Avoid overlapping requests.
        if continuation != nil { throw AuthError.failed("이미 진행 중인 Apple 로그인이 있습니다.") }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - ASAuthorizationControllerDelegate

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { continuation = nil }
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AuthError.invalidResponse)
            return
        }
        let fullName = [cred.fullName?.givenName, cred.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        let identityToken = cred.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let authCode = cred.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        let identity = AuthenticatedIdentity(
            provider: .apple,
            providerUserID: cred.user,
            email: cred.email,
            fullName: fullName.isEmpty ? nil : fullName,
            identityToken: identityToken,
            accessToken: authCode // Apple's authorization code (for backend token exchange)
        )
        continuation?.resume(returning: identity)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        defer { continuation = nil }
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            continuation?.resume(throwing: AuthError.cancelled)
        } else {
            continuation?.resume(throwing: AuthError.failed(error.localizedDescription))
        }
    }

    // MARK: - Presentation anchor

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        AuthPresentation.keyWindow()
    }
}

/// Shared helper to resolve a presentation anchor for the auth UI.
enum AuthPresentation {
    @MainActor
    static func keyWindow() -> ASPresentationAnchor {
        #if canImport(UIKit)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first
        return window ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
