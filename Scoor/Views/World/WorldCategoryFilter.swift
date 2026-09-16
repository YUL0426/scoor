//
//  WorldCategoryFilter.swift
//  Scoor
//
//  World 탭 상단의 카테고리 채널 칩 strip.
//  - “전체 / 스포츠 / 정치 / …” — Toss Community 카테고리 톤.
//  - 활성 칩: 흰색 배경 + 검정 텍스트. 비활성: 옅은 회색.
//

import SwiftUI

struct WorldCategoryFilter: View {

    @Binding var selected: WorldCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                chip(label: String(localized: "전체"), emoji: nil, isOn: selected == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = nil }
                }

                ForEach(WorldCategory.allCases) { c in
                    chip(label: c.label, emoji: c.emoji, isOn: selected == c) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selected = (selected == c) ? nil : c
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func chip(label: String, emoji: String?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let e = emoji {
                    Text(e).font(.system(size: 16))
                } else {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 16))
                }
                Text(label)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(isOn ? ScoorPalette.bgBase : ScoorPalette.inkSecondary)
            .frame(minHeight: 24)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(
                    isOn ? ScoorPalette.inkPrimary : Color.white.opacity(0.06)
                )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        VStack(spacing: 24) {
            WorldCategoryFilter(selected: .constant(nil))
            WorldCategoryFilter(selected: .constant(.crypto))
        }
    }
    .environment(\.colorScheme, .dark)
}
