import SwiftUI

/// Incoming social activity. Empty until the social activity backend is available.
struct ActivityView: View {
    @State private var selected = "모두"
    private let filters = ["모두", "팔로우", "대화", "언급", "리포스트"]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("알림")
                .font(.system(size: 30, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters, id: \.self) { filter in
                        Button { selected = filter } label: {
                            Text(LocalizedStringKey(filter))
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 22)
                                .frame(minHeight: 44)
                                .foregroundStyle(selected == filter ? ScoorPalette.bgBase : ScoorPalette.inkPrimary)
                                .background(selected == filter ? ScoorPalette.inkPrimary : ScoorPalette.bgRaised, in: Capsule())
                                .overlay(Capsule().stroke(ScoorPalette.hairline, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("activity-filter-\(filter)")
                        .accessibilityAddTraits(selected == filter ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 20)
            }
            VStack(spacing: 14) {
                Image(systemName: selected == "리포스트" ? "arrow.2.squarepath" : "heart")
                    .font(.system(size: 34, weight: .light))
                Text(selected == "모두" ? String(localized: "아직 알림이 없어요") : String(localized: "아직 \(String(localized: String.LocalizationValue(selected))) 알림이 없어요"))
                    .font(.system(size: 17, weight: .semibold))
                Text("새로운 소식이 생기면 여기에서 확인하세요")
                    .font(.system(size: 14))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
            .foregroundStyle(ScoorPalette.inkSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(ScoorPalette.inkPrimary)
        .background(ScoorPalette.bgBase.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }
}
