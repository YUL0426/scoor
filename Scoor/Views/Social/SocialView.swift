//
//  SocialView.swift
//  Scoor
//
//  Tab 4: Social feed (placeholder for v2).
//

import SwiftUI

struct SocialView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.scoorRed.opacity(0.3))

            Text("Social")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text("Connect with friends and\nsee their daily scores")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.scoorBackground)
        .navigationTitle("Social")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SocialView()
    }
}
