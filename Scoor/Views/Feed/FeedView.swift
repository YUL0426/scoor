//
//  FeedView.swift
//  Scoor
//
//  Toss Community 톤의 텍스트 우선 피드.
//  - 시네마틱 hero/도시 쇼케이스 제거
//  - 상단 sticky: 작은 헤더 + 정렬 탭 + 필터 칩
//  - 본문: hairline divider로 구분된 flat 카드 스트림
//  - pull-to-refresh, 무한 스크롤(목 데이터 반복)으로 “살아 있는 피드” 감
//

import SwiftUI

struct FeedView: View {

    // MARK: - State

    @State private var sort: FeedSort = .live
    @State private var selectedMood: Mood? = nil
    @State private var entries: [FeedEntry] = MockFeed.entries
    @State private var isRefreshing = false

    // MARK: - Derived

    private var filtered: [FeedEntry] {
        guard let mood = selectedMood else { return entries }
        return entries.filter {
            $0.primaryMood == mood || $0.extraTags.contains(mood)
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader

                LivePulseView(pulses: MockFeed.pulses)
                    .padding(.top, 6)

                sortTabs
                    .padding(.top, 10)

                Divider().background(ScoorPalette.hairlineSoft)

                MoodFilterView(selected: $selectedMood)
                    .padding(.vertical, 10)

                Divider().background(ScoorPalette.hairline)

                feedStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: selectedMood)
        .animation(.easeInOut(duration: 0.18), value: sort)
    }

    // MARK: - Top header (얇은 앱바)

    private var topHeader: some View {
        HStack(spacing: 8) {
            Text("Feed")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(ScoorPalette.inkPrimary)

            statusDot
                .padding(.leading, 2)

            Spacer()

            // 오늘 기록 수 + 평균 — 작은 stat
            HStack(spacing: 6) {
                Text("오늘")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text(CompactCount.format(MockFeed.todayCount))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .monospacedDigit()
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text("평균 \(MockFeed.todayAverage)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ScoorPalette.accent)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var statusDot: some View {
        Circle()
            .fill(ScoorPalette.accent)
            .frame(width: 6, height: 6)
            .shadow(color: ScoorPalette.accent.opacity(0.6), radius: 4)
    }

    // MARK: - Sort tabs (실시간 / 인기 / 비슷한 기분)

    private var sortTabs: some View {
        HStack(spacing: 0) {
            ForEach(FeedSort.allCases) { mode in
                sortTab(mode)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func sortTab(_ mode: FeedSort) -> some View {
        Button {
            sort = mode
        } label: {
            VStack(spacing: 6) {
                Text(mode.rawValue)
                    .font(.system(size: 14,
                                  weight: sort == mode ? .bold : .medium))
                    .foregroundStyle(
                        sort == mode ? ScoorPalette.inkPrimary
                                     : ScoorPalette.inkTertiary
                    )
                Rectangle()
                    .fill(sort == mode ? ScoorPalette.accent : Color.clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Feed stream (flat + divider)

    private var feedStream: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filtered.indices, id: \.self) { i in
                    FeedCardView(entry: binding(for: filtered[i].id))
                    Divider().background(ScoorPalette.hairline)
                }

                if filtered.isEmpty {
                    emptyState
                }

                bottomSpacer
            }
        }
        .refreshable { await refresh() }
    }

    /// 필터된 배열은 복사본이라 바인딩이 안되므로 id 기반으로 원본 인덱스를 찾는다.
    private func binding(for id: UUID) -> Binding<FeedEntry> {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else {
            // 안전망 — 실제로는 도달하지 않음.
            return .constant(entries[0])
        }
        return $entries[idx]
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("아직 이 감정의 글이 없어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text("다른 감정을 보거나 직접 한 줄 남겨볼까요?")
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    /// ScoorTabBar(64) + FAB lift(18) + 안전 여유.
    private var bottomSpacer: some View {
        Color.clear.frame(height: 120)
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        isRefreshing = true
        // 데모 — 항목 순서를 살짝 섞고, 첫 항목 시간 갱신.
        try? await Task.sleep(nanoseconds: 600_000_000)
        if !entries.isEmpty {
            entries.swapAt(0, min(1, entries.count - 1))
        }
        isRefreshing = false
    }
}

#Preview {
    FeedView()
}
