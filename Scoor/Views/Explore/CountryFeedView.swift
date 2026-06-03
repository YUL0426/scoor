//
//  CountryFeedView.swift
//  Scoor
//
//  Pushed from Explore map when tapping a country bubble.
//  Design ref: /design/2. world/worldwide_scoor_map_1
//

import SwiftUI

struct CountryFeedView: View {
    let country: String

    var body: some View {
        VStack(spacing: 0) {
            // Placeholder feed
            VStack(spacing: 16) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 48))
                    .foregroundColor(.scoorRed.opacity(0.3))

                Text("\(country.isEmpty ? "Country" : country) Feed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                Text("User scores will appear here")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(country.uppercased() + " FEED")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.scoorBackground)
    }
}

#Preview {
    NavigationStack {
        CountryFeedView(country: "Korea")
    }
}
