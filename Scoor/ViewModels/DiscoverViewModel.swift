//
//  DiscoverViewModel.swift
//  Scoor
//
//  사용자 탐색 화면의 상태/로직.
//  - 인기 사용자 / 추천 사용자 / 추천 콘텐츠 로드
//  - 팔로우 토글(낙관적 + 영속 + 롤백)
//  - 검색어 필터, 로딩/빈/에러 상태
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published var data: DiscoverData = .empty
    @Published var phase: LoadPhase = .idle
    @Published var query: String = ""
    @Published var transientError: String? = nil

    private let service: SocialServiceProtocol

    init(service: SocialServiceProtocol) {
        self.service = service
    }

    // MARK: - Derived (검색 필터)

    var filteredPopular: [DiscoverUser] { filter(data.popularUsers) }
    var filteredRecommended: [DiscoverUser] { filter(data.recommendedUsers) }

    private func filter(_ users: [DiscoverUser]) -> [DiscoverUser] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter {
            $0.identity.name.lowercased().contains(q) || $0.tagline.lowercased().contains(q)
        }
    }

    // MARK: - Load

    func loadIfNeeded() async {
        guard data.isEmpty, phase == .idle || phase == .loading else { return }
        await load()
    }

    func load() async {
        phase = .loading
        let result = await service.loadDiscover()
        data = result
        phase = result.isEmpty ? .empty : .loaded
    }

    func refresh() async {
        let result = await service.loadDiscover()
        data = result
        phase = result.isEmpty ? .empty : .loaded
    }

    // MARK: - Follow

    func toggleFollow(_ user: DiscoverUser) {
        let nowFollowing = !user.isFollowing
        setFollowingLocally(user.id, nowFollowing)   // 낙관적
        Task {
            do {
                try await service.setFollowing(nowFollowing, userName: user.identity.name)
            } catch {
                setFollowingLocally(user.id, !nowFollowing)   // 롤백
                transientError = "팔로우 상태 저장에 실패했어요."
            }
        }
    }

    private func setFollowingLocally(_ id: UUID, _ following: Bool) {
        func apply(_ list: [DiscoverUser]) -> [DiscoverUser] {
            list.map { u in
                guard u.id == id else { return u }
                var copy = u
                copy.isFollowing = following
                return copy
            }
        }
        data.popularUsers = apply(data.popularUsers)
        data.recommendedUsers = apply(data.recommendedUsers)
    }
}
