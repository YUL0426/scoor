//
//  ExploreMapView.swift
//  Scoor
//
//  Tab 1: Interactive world map with score speech bubbles.
//  Design ref: /design/2. world/worldwide_scoor_map_2
//

import SwiftUI
import MapKit

struct ExploreMapView: View {
    @State private var showCountryFeed = false
    @State private var selectedCountry: String = ""

    var body: some View {
        ZStack {
            // Map background
            Color.scoorBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header: scoor! logo + GLOBAL/LOCAL toggle
                ExploreHeaderView()

                // Search bar
                ExploreSearchBar()
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                Spacer()

                // Placeholder for map content
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.scoorRed.opacity(0.3))

                    Text("World Map")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Score bubbles will appear here")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // World Average bottom bar
                WorldAverageBar()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCountryFeed) {
            CountryFeedView(country: selectedCountry)
        }
    }
}

// MARK: - Subcomponents (Stubs)

struct ExploreHeaderView: View {
    var body: some View {
        HStack {
            ScoorLogo(size: 22, variant: .red)
            Spacer()
            GlobalLocalToggle()
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

struct ExploreSearchBar: View {
    @State private var searchText = ""

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Find a country or city...", text: $searchText)
                .font(.system(size: 14, weight: .medium))

            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.scoorLightGray)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

struct GlobalLocalToggle: View {
    @State private var isGlobal = true

    var body: some View {
        HStack(spacing: 0) {
            toggleButton("GLOBAL", isSelected: isGlobal) { isGlobal = true }
            toggleButton("LOCAL", isSelected: !isGlobal) { isGlobal = false }
        }
        .padding(4)
        .background(Color.scoorLightGray)
        .clipShape(Capsule())
    }

    private func toggleButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(isSelected ? .scoorRed : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? .white : .clear)
                .clipShape(Capsule())
        }
    }
}

struct WorldAverageBar: View {
    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.scoorRed.opacity(0.1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.scoorRed)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("WORLD AVERAGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("7.5")
                            .font(.system(size: 20, weight: .black))
                        Text("+0.2")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("Feed")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.scoorRed)
            }
        }
        .padding(16)
        .background(.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        ExploreMapView()
    }
}
