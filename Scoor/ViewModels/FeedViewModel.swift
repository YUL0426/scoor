//
//  FeedViewModel.swift
//  Scoor
//
//  Feed 탭(타임라인)의 상태/로직.
//  - 서비스 기반 데이터 로드(페이지네이션/새로고침)
//  - 좋아요 낙관적 업데이트 + 영속 + 실패 롤백
//  - 정렬(실시간/인기/비슷한 기분) + 감정 필터
//  - 로딩/빈/에러 상태(LoadPhase)
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class FeedViewModel: ObservableObject {

    @Published var entries: [FeedEntry] = []
    @Published var phase: LoadPhase = .idle
    @Published var sort: FeedSort = .live
    @Published var selectedMood: Mood? = nil
    @Published var isLoadingMore = false
    @Published private(set) var canLoadMore = true
    /// 일시적 에러 토스트 메시지.
    @Published var transientError: String? = nil

    private let service: SocialServiceProtocol
    private let pageSize: Int
    private var loadedPages = 0

    init(service: SocialServiceProtocol, pageSize: Int = 8) {
        self.service = service
        self.pageSize = pageSize
    }

    // MARK: - Derived

    /// 감정 필터 + 정렬 적용된 표시용 목록.
    var visible: [FeedEntry] {
        var list = entries
        if let mood = selectedMood {
            list = list.filter { $0.primaryMood == mood || $0.extraTags.contains(mood) }
        }
        switch sort {
        case .live:    list.sort { $0.postedAt > $1.postedAt }
        case .popular: list.sort { $0.reactions.likes > $1.reactions.likes }
        case .similar: list.sort { $0.reactions.empathyTotal > $1.reactions.empathyTotal }
        }
        return list
    }

    var isEmpty: Bool { phase == .empty || (phase == .loaded && visible.isEmpty) }

    // MARK: - Load

    func loadIfNeeded() async {
        guard entries.isEmpty, phase == .idle || phase == .loading else { return }
        await load()
    }

    func load() async {
        phase = .loading
        loadedPages = 0
        canLoadMore = true
        let page = await service.loadFeed(page: 0, pageSize: pageSize)
        entries = page
        loadedPages = 1
        phase = page.isEmpty ? .empty : .loaded
    }

    func refresh() async {
        let page = await service.loadFeed(page: 0, pageSize: pageSize)
        entries = page
        loadedPages = 1
        canLoadMore = true
        phase = page.isEmpty ? .empty : .loaded
    }

    func loadMoreIfNeeded(currentItem: FeedEntry) async {
        guard canLoadMore, !isLoadingMore, phase == .loaded else { return }
        // 마지막에서 3번째에 닿으면 다음 페이지 프리페치.
        let thresholdIndex = max(0, entries.count - 3)
        guard let idx = entries.firstIndex(of: currentItem), idx >= thresholdIndex else { return }
        await loadMore()
    }

    func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        let next = await service.loadFeed(page: loadedPages, pageSize: pageSize)
        // 무한 합성을 막기 위한 상한(예: 6페이지).
        if next.isEmpty || loadedPages >= 6 {
            canLoadMore = false
        } else {
            // 중복 id 방지(결정적 합성이라 이론상 없지만 안전망).
            let known = Set(entries.map(\.id))
            entries.append(contentsOf: next.filter { !known.contains($0.id) })
            loadedPages += 1
        }
        isLoadingMore = false
    }

    /// 댓글 추가/삭제 후 보이는 항목들의 카운트만 서버 기준으로 갱신.
    func reloadOverlays() async {
        guard loadedPages > 0 else { return }
        var rebuilt: [FeedEntry] = []
        for page in 0..<loadedPages {
            rebuilt.append(contentsOf: await service.loadFeed(page: page, pageSize: pageSize))
        }
        // 기존 순서(좋아요 등 사용자 조작 반영) 유지하며 교체.
        let byId = Dictionary(rebuilt.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        entries = entries.map { byId[$0.id] ?? $0 }
    }

    // MARK: - Binding helper

    /// 필터/정렬된 목록은 복사본이므로 id로 원본 인덱스를 찾아 바인딩한다.
    func binding(for id: UUID) -> Binding<FeedEntry>? {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.entries[idx] },
            set: { self.entries[idx] = $0 }
        )
    }

    // MARK: - Likes (낙관적 → 영속 → 롤백)

    /// ReactionBar가 바인딩을 이미 토글한 뒤 호출. 영속만 담당하고 실패 시 되돌린다.
    func persistLike(entryId: UUID, nowLiked: Bool) {
        Task {
            do {
                try await service.setLike(postId: entryId, liked: nowLiked)
            } catch {
                // 롤백
                if let idx = entries.firstIndex(where: { $0.id == entryId }) {
                    var r = entries[idx].reactions
                    r.likedByMe = !nowLiked
                    r.likes = max(0, r.likes + (nowLiked ? -1 : 1))
                    entries[idx].reactions = r
                }
                transientError = "좋아요 저장에 실패했어요. 다시 시도해주세요."
            }
        }
    }
}
