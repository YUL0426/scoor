//
//  ProfileAvatarView.swift
//  Scoor
//
//  Single source of truth for rendering a user's avatar across Home / My Page /
//  profile edit. Resolution order: custom image (local file) → emoji glyph →
//  person icon. Optionally overlays a provider badge (Apple/Google).
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ProfileAvatarView: View {
    var imageURL: URL?
    var emoji: String?
    var size: CGFloat = 56
    var provider: AuthProvider? = nil

    private var uiImage: UIImage? {
        guard let imageURL, imageURL.isFileURL else { return nil }
        return UIImage(contentsOfFile: imageURL.path)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            base
                .frame(width: size, height: size)
                .clipShape(Circle())

            if let provider, let badge = badgeSymbol(for: provider) {
                Image(systemName: badge)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(size * 0.10)
                    .background(Circle().fill(badgeColor(for: provider)))
                    .overlay(Circle().stroke(DesignTokens.backgroundColor, lineWidth: size * 0.04))
                    .offset(x: size * 0.04, y: size * 0.04)
            }
        }
        .accessibilityIdentifier("profile-avatar")
    }

    @ViewBuilder
    private var base: some View {
        if let uiImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let emoji, !emoji.isEmpty {
            Text(emoji)
                .font(.system(size: size * 0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.primaryColor.opacity(0.15))
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(DesignTokens.primaryColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.primaryColor.opacity(0.15))
        }
    }

    private func badgeSymbol(for provider: AuthProvider) -> String? {
        switch provider {
        case .apple:  return "apple.logo"
        case .google: return "g.circle.fill"
        case .email:  return "envelope.fill"
        }
    }

    private func badgeColor(for provider: AuthProvider) -> Color {
        switch provider {
        case .apple:  return .black
        case .google: return Color(red: 0.26, green: 0.52, blue: 0.96)
        case .email:  return DesignTokens.primaryColor
        }
    }
}
