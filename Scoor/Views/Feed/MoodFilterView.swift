//
//  MoodFilterView.swift
//  Scoor
//
//  Toss Community 톤의 카테고리 칩 row.
//  - 전체 / 행복 / 번아웃 / 외로움 / 고요 / 회복 / 일 / 사랑 / 새벽 / 학생
//  - 활성 칩은 흰색 배경 + 검정 텍스트 (Toss 스타일)
//  - 비활성 칩은 옅은 회색 배경
//

import SwiftUI

struct MoodFilterView: View {

    @Binding var selected: Mood?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(label: "전체", isOn: selected == nil) {
                    withAnimation(.easeInOut(duration: 0.18)) { selected = nil }
                }
                ForEach(Mood.allCases) { mood in
                    chip(label: mood.label, isOn: selected == mood) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selected = (selected == mood) ? nil : mood
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    @ViewBuilder
    private func chip(label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(ScoorType.chip)
                .foregroundStyle(
                    isOn ? ScoorPalette.bgBase : ScoorPalette.inkSecondary
                )
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    Capsule().fill(
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
            MoodFilterView(selected: .constant(nil))
            MoodFilterView(selected: .constant(.burnout))
        }
    }
    .environment(\.colorScheme, .dark)
}
