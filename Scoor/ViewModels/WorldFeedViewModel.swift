//
//  WorldFeedViewModel.swift
//  Scoor
//
//  World 탭(토픽 피드)의 상태/로직.
//  - 토픽 + 토픽-태깅 글 로드(페이지네이션/새로고침)
//  - 카테고리 필터 + 정렬(실시간/뜨거움/급상승)
//  - 좋아요 낙관적 업데이트 + 영속 + 롤백
//  - 로딩/빈/에러 상태
//
//  ※ 기존 `WorldViewModel`(월드 지도/국가 피드)과 별개의 화면이라 이름을 분리한다.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class WorldFeedViewModel: ObservableObject {

    @Published var topics: [WorldTopic] = []
    @Published var posts: [WorldPost] = []
    @Published var phase: LoadPhase = .idle
    @Published var sort: WorldSort = .live
    @Published var category: WorldCategory? = nil
    @Published var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    @Published var transientError: String? = nil

    private let service: SocialServiceProtocol
    private let pageSize: Int
    private var loadedPages = 0

    init(service: SocialServiceProtocol, pageSize: Int = 8) {
        self.service = service
        self.pageSize = pageSize
    }

    // MARK: - Derived

    var trendingTopics: [WorldTopic] {
        if let cat = category { return topics.filter { $0.category == cat } }
        return topics.sorted { a, b in
            let ah = heatRank(a.heat), bh = heatRank(b.heat)
            if ah != bh { return ah < bh }
            return a.postsCount > b.postsCount
        }
    }

    var visiblePosts: [WorldPost] {
        var list = posts
        if let cat = category { list = list.filter { $0.topic.category == cat } }
        switch sort {
        case .live:     list.sort { $0.postedAt > $1.postedAt }
        case .hot:      list.sort { $0.reactions.likes + $0.reactions.comments > $1.reactions.likes + $1.reactions.comments }
        case .trending: list.sort { $0.topic.scoreDelta > $1.topic.scoreDelta }
        }
        return list
    }

    var isEmpty: Bool { phase == .loaded && visiblePosts.isEmpty }

    private func heatRank(_ h: TopicHeat) -> Int {
        switch h {
        case .hot: return 0
        case .rising: return 1
        case .fresh: return 2
        case .falling: return 3
        case .calm: return 4
        }
    }

    // MARK: - Load

    func loadIfNeeded() async {
        guard posts.isEmpty, phase == .idle || phase == .loading else { return }
        await load()
    }

    func load() async {
        phase = .loading
        loadedPages = 0
        canLoadMore = true
        topics = await service.loadTopics()
        let page = await service.loadWorldPosts(page: 0, pageSize: pageSize)
        posts = page
        loadedPages = 1
        phase = page.isEmpty ? .empty : .loaded
    }

    func refresh() async {
        topics = await service.loadTopics()
        let page = await service.loadWorldPosts(page: 0, pageSize: pageSize)
        posts = page
        loadedPages = 1
        canLoadMore = true
        phase = page.isEmpty ? .empty : .loaded
    }

    func loadMoreIfNeeded(currentItem: WorldPost) async {
        guard canLoadMore, !isLoadingMore, phase == .loaded else { return }
        let thresholdIndex = max(0, posts.count - 3)
        guard let idx = posts.firstIndex(of: currentItem), idx >= thresholdIndex else { return }
        await loadMore()
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        let next = await service.loadWorldPosts(page: loadedPages, pageSize: pageSize)
        if next.isEmpty || loadedPages >= 6 {
            canLoadMore = false
        } else {
            let known = Set(posts.map(\.id))
            posts.append(contentsOf: next.filter { !known.contains($0.id) })
            loadedPages += 1
        }
        isLoadingMore = false
    }

    func reloadOverlays() async {
        guard loadedPages > 0 else { return }
        var rebuilt: [WorldPost] = []
        for page in 0..<loadedPages {
            rebuilt.append(contentsOf: await service.loadWorldPosts(page: page, pageSize: pageSize))
        }
        let byId = Dictionary(rebuilt.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        posts = posts.map { byId[$0.id] ?? $0 }
    }

    // MARK: - Binding

    func binding(for id: UUID) -> Binding<WorldPost>? {
        guard let idx = posts.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.posts[idx] },
            set: { self.posts[idx] = $0 }
        )
    }

    // MARK: - Likes

    func persistLike(postId: UUID, nowLiked: Bool) {
        Task {
            do {
                try await service.setLike(postId: postId, liked: nowLiked)
            } catch {
                if let idx = posts.firstIndex(where: { $0.id == postId }) {
                    var r = posts[idx].reactions
                    r.likedByMe = !nowLiked
                    r.likes = max(0, r.likes + (nowLiked ? -1 : 1))
                    posts[idx].reactions = r
                }
                transientError = "좋아요 저장에 실패했어요. 다시 시도해주세요."
            }
        }
    }
}
