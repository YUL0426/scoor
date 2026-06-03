//
//  WorldView.swift
//  Scoor
//
//  새 World 탭 — “세계가 실시간으로 감정 점수를 매기는 토픽 피드”.
//
//  구성(위→아래):
//    1. 얇은 헤더 (제목 + 지금 활동 통계)
//    2. WORLD PULSE 티커
//    3. 정렬 탭 (실시간 / 지금 뜨거움 / 급상승)
//    4. 카테고리 칩 strip (스포츠 / 정치 / 주식 / 코인 …)
//    5. “지금 뜨거운 토픽” 가로 스크롤 (토픽 미니카드)
//    6. 토픽-태깅된 유저 글 스트림 (flat + hairline divider)
//

import SwiftUI

struct WorldView: View {

    // MARK: - State

    @State private var sort: WorldSort = .live
    @State private var category: WorldCategory? = nil
    @State private var posts: [WorldPost] = MockWorld.posts
    @State private var topics: [WorldTopic] = MockWorld.topics
    @State private var selectedTopic: WorldTopic? = nil

    // MARK: - Derived

    private var filteredPosts: [WorldPost] {
        MockWorld.postsIn(category).filter { p in
            posts.contains(where: { $0.id == p.id })
        }
        // 우리는 posts 배열 자체에서 binding을 줘야 하므로 id로 다시 매핑.
    }

    private var visiblePosts: [WorldPost] {
        if let cat = category {
            return posts.filter { $0.topic.category == cat }
        }
        return posts
    }

    private var trendingTopics: [WorldTopic] {
        if let cat = category {
            return topics.filter { $0.category == cat }
        }
        // 정렬: heat가 hot/rising 우선, 그 다음 글 수.
        return topics.sorted { a, b in
            let ah = heatRank(a.heat), bh = heatRank(b.heat)
            if ah != bh { return ah < bh }
            return a.postsCount > b.postsCount
        }
    }

    private func heatRank(_ h: TopicHeat) -> Int {
        switch h {
        case .hot: return 0
        case .rising: return 1
        case .fresh: return 2
        case .falling: return 3
        case .calm: return 4
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader
                WorldPulseStrip(pulses: MockWorld.pulses)
                    .padding(.top, 6)
                sortTabs
                    .padding(.top, 10)
                Divider().background(ScoorPalette.hairlineSoft)
                WorldCategoryFilter(selected: $category)
                    .padding(.vertical, 10)
                Divider().background(ScoorPalette.hairline)

                postStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: category)
        .animation(.easeInOut(duration: 0.18), value: sort)
        .sheet(item: $selectedTopic) { topic in
            TopicDetailView(topic: topic)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Top header

    private var topHeader: some View {
        HStack(spacing: 8) {
            Text("World")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(ScoorPalette.inkPrimary)
            statusDot
                .padding(.leading, 2)

            Spacer()

            HStack(spacing: 6) {
                Text("지금")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text(CompactCount.format(MockWorld.liveActiveCount))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .monospacedDigit()
                Text("·")
                    .font(.system(size: 11))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text("평균 \(MockWorld.liveAverage)")
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

    // MARK: - Sort tabs

    private var sortTabs: some View {
        HStack(spacing: 0) {
            ForEach(WorldSort.allCases) { mode in
                sortTab(mode)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func sortTab(_ mode: WorldSort) -> some View {
        Button { sort = mode } label: {
            VStack(spacing: 6) {
                Text(mode.rawValue)
                    .font(.system(size: 14, weight: sort == mode ? .bold : .medium))
                    .foregroundStyle(sort == mode ? ScoorPalette.inkPrimary
                                                  : ScoorPalette.inkTertiary)
                Rectangle()
                    .fill(sort == mode ? ScoorPalette.accent : Color.clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Post stream

    private var postStream: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                WorldTrendingRow(topics: trendingTopics,
                                 onSelect: { selectedTopic = $0 })
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                Divider().background(ScoorPalette.hairline)

                ForEach(visiblePosts.indices, id: \.self) { _ in EmptyView() } // 워밍업

                ForEach(visiblePosts) { post in
                    WorldPostCardView(
                        post: binding(for: post.id),
                        onTopicTap: { selectedTopic = post.topic }
                    )
                    Divider().background(ScoorPalette.hairline)
                }

                if visiblePosts.isEmpty {
                    emptyState
                }

                bottomSpacer
            }
        }
        .refreshable { await refresh() }
    }

    private func binding(for id: UUID) -> Binding<WorldPost> {
        guard let idx = posts.firstIndex(where: { $0.id == id }) else {
            return .constant(posts[0])
        }
        return $posts[idx]
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("이 채널엔 아직 글이 없어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text("다른 카테고리도 둘러볼까요?")
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var bottomSpacer: some View {
        Color.clear.frame(height: 120)
    }

    // MARK: - Refresh

    @MainActor
    private func refresh() async {
        try? await Task.sleep(nanoseconds: 600_000_000)
        if posts.count >= 2 { posts.swapAt(0, 1) }
    }
}

#Preview {
    WorldView()
}
