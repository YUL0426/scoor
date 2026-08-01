//
//  WorldView.swift
//  Scoor
//
//  새 World 탭 — "세계가 실시간으로 감정 점수를 매기는 토픽 피드".
//  - 데이터: SocialService 기반(WorldFeedViewModel) — 좋아요/댓글 영속, 페이지네이션, 새로고침
//  - 구성: 헤더 / WORLD PULSE / 정렬 / 카테고리 필터 / 트렌딩 토픽 / 토픽-태깅 글 스트림
//  - 로딩/빈/에러 상태 처리
//

import SwiftUI

struct WorldView: View {

    @EnvironmentObject private var appServices: AppServices
    @StateObject private var vm: WorldFeedViewModel

    private let socialService: SocialServiceProtocol

    @State private var selectedTopic: WorldTopic? = nil
    @State private var commentTarget: WorldPost? = nil
    @State private var myName: String = "나"
    private let mySeed = 1

    init(socialService: SocialServiceProtocol, worldService: RemoteWorldService? = nil) {
        self.socialService = socialService
        _vm = StateObject(wrappedValue: WorldFeedViewModel(
            service: socialService,
            world: worldService
        ))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader
                // 토픽은 서버에서 오지만 아래 글 스트림은 아직 시드다(Phase 2에서
                // 전환). 스트림이 가짜인 동안에는 배너를 유지해야 한다 — 진짜
                // 토픽이 생겼다고 배너를 떼면 가짜 글이 진짜처럼 보인다(P0-1).
                PreviewContentBanner()
                    .padding(.top, 4)
                // 펄스 티커도 시드 수치라 실데이터(/pulse) 연동 전까지 감춘다.
                if !vm.topicsAreLive {
                    WorldPulseStrip(pulses: MockWorld.pulses)
                        .padding(.top, 6)
                }
                sortTabs
                    .padding(.top, 10)
                Divider().background(ScoorPalette.hairlineSoft)
                WorldCategoryFilter(selected: $vm.category)
                    .padding(.vertical, 10)
                Divider().background(ScoorPalette.hairline)

                postStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: vm.category)
        .animation(.easeInOut(duration: 0.18), value: vm.sort)
        .task {
            await vm.loadIfNeeded()
            await refreshMyName()
        }
        // Reflect profile edits made in My Page without an app restart (BUG-008).
        .onReceive(NotificationCenter.default.publisher(for: .scoorUserProfileDidChange)) { _ in
            Task { await refreshMyName() }
        }
        .sheet(item: $selectedTopic) { topic in
            TopicDetailView(topic: topic,
                            socialService: socialService,
                            worldService: appServices.worldService,
                            moderationService: appServices.moderationService)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $commentTarget) { post in
            CommentsSheet(
                postId: post.id,
                headerPreview: post.message,
                service: socialService,
                currentUserName: myName,
                currentUserSeed: mySeed,
                onChange: { Task { await vm.reloadOverlays() } }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    /// Re-read the current user's display name from the live profile (BUG-008).
    private func refreshMyName() async {
        if let user = await appServices.userService.getCurrentUser() {
            myName = user.username.isEmpty ? "나" : user.username
        }
    }

    // MARK: - Top header

    private var topHeader: some View {
        HStack(spacing: 8) {
            Text("World")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .accessibilityIdentifier("world.header")
            // 접속자 수·평균 점수를 표시하던 자리. 그 수치는 하드코딩된
            // 가짜였고(P0-1), 실데이터는 /pulse 집계가 붙어야 나온다(C9).
            // 없는 데이터를 지어내느니 자리를 비워둔다.
            if !vm.topicsAreLive {
                statusDot.padding(.leading, 2)
            }

            Spacer()

            if vm.topicsAreLive {
                Text("토픽 \(vm.topics.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .monospacedDigit()
            } else {
                HStack(spacing: 6) {
                    Text("지금")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                    Text(CompactCount.format(MockWorld.liveActiveCount))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                        .monospacedDigit()
                    Text("·").font(.system(size: 11)).foregroundStyle(ScoorPalette.inkTertiary)
                    Text("평균 \(MockWorld.liveAverage)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ScoorPalette.accent)
                        .monospacedDigit()
                }
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
            ForEach(WorldSort.allCases) { mode in sortTab(mode) }
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func sortTab(_ mode: WorldSort) -> some View {
        Button { vm.sort = mode } label: {
            VStack(spacing: 6) {
                Text(mode.rawValue)
                    .font(.system(size: 14, weight: vm.sort == mode ? .bold : .medium))
                    .foregroundStyle(vm.sort == mode ? ScoorPalette.inkPrimary : ScoorPalette.inkTertiary)
                Rectangle()
                    .fill(vm.sort == mode ? ScoorPalette.accent : Color.clear)
                    .frame(height: 2)
            }
            .padding(.trailing, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Post stream

    @ViewBuilder
    private var postStream: some View {
        switch vm.phase {
        case .idle, .loading:
            VStack { Spacer(); ProgressView().tint(ScoorPalette.inkSecondary); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            errorState(msg)
        case .empty, .loaded:
            loadedStream
        }
    }

    private var loadedStream: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                WorldTrendingRow(topics: vm.trendingTopics,
                                 onSelect: { selectedTopic = $0 })
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                Divider().background(ScoorPalette.hairline)

                ForEach(vm.visiblePosts) { post in
                    if let binding = vm.binding(for: post.id) {
                        WorldPostCardView(
                            post: binding,
                            onTopicTap: { selectedTopic = post.topic },
                            onLikeToggle: { liked in vm.persistLike(postId: post.id, nowLiked: liked) },
                            onCommentTap: { commentTarget = post }
                        )
                        .onAppear { Task { await vm.loadMoreIfNeeded(currentItem: post) } }
                        Divider().background(ScoorPalette.hairline)
                    }
                }

                if vm.visiblePosts.isEmpty { emptyState }
                if vm.isLoadingMore { ProgressView().tint(ScoorPalette.inkTertiary).padding(.vertical, 18) }
                bottomSpacer
            }
        }
        .refreshable { await vm.refresh() }
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "wifi.exclamationmark").font(.system(size: 32)).foregroundStyle(ScoorPalette.inkTertiary)
            Text("월드 피드를 불러오지 못했어요").font(.system(size: 15, weight: .semibold)).foregroundStyle(ScoorPalette.inkSecondary)
            Text(msg).font(.system(size: 12)).foregroundStyle(ScoorPalette.inkTertiary)
            Button("다시 시도") { Task { await vm.load() } }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(ScoorPalette.accent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var bottomSpacer: some View { Color.clear.frame(height: 120) }
}

#Preview {
    WorldView(socialService: MockSocialService())
        .environmentObject(AppServices())
}
