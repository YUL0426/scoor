//
//  KeyboardDismiss.swift
//  Scoor
//
//  Global "tap empty space to dismiss the keyboard" support (BUG-001).
//
//  Implemented at the window level with a `UITapGestureRecognizer` that does NOT
//  cancel touches in the view, so buttons / scrolling / existing focus logic keep
//  working — a tap just additionally resigns first responder. The recognizer is a
//  no-op when no keyboard is shown. Installed once at the app root via
//  `installGlobalKeyboardDismiss()`, so it covers every main-window screen
//  (Home / World / Feed / My Page / Guestbook / Onboarding).
//

import SwiftUI

#if canImport(UIKit)
import UIKit

/// Marker subclass so we can detect (and avoid duplicating) our own recognizer.
private final class ScoorKeyboardDismissRecognizer: UITapGestureRecognizer {}

/// Installs and owns the app-wide keyboard-dismiss tap recognizer.
final class GlobalKeyboardDismiss: NSObject, UIGestureRecognizerDelegate {

    static let shared = GlobalKeyboardDismiss()

    /// Attach the recognizer to the active key window if not already present.
    /// Safe to call repeatedly (e.g. on every root `onAppear`).
    func installIfNeeded() {
        guard let window = Self.activeKeyWindow() else { return }
        let alreadyInstalled = window.gestureRecognizers?
            .contains { $0 is ScoorKeyboardDismissRecognizer } ?? false
        guard !alreadyInstalled else { return }

        let tap = ScoorKeyboardDismissRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false   // let taps still reach buttons / lists
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    // Recognize alongside buttons, scroll views, and other taps.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }

    private static func activeKeyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return active?.windows.first { $0.isKeyWindow } ?? active?.windows.first
    }
}

extension View {
    /// Enable app-wide tap-to-dismiss-keyboard. Apply once near the app root.
    func installGlobalKeyboardDismiss() -> some View {
        onAppear { GlobalKeyboardDismiss.shared.installIfNeeded() }
    }
}
#else
extension View {
    func installGlobalKeyboardDismiss() -> some View { self }
}
#endif
