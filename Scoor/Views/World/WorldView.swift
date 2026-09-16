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

    @State private var liveScores: [WorldScoreFeedRow] = []
    @State private var scoreFeedLoading = false
    @State private var scoreFeedError: String?
    @State private var scoreFeedHasMore = true
    @State private var scoreFeedGeneration = UUID()
    @State private var topicSearch = ""
    @State private var searchedTopics: [WorldTopic] = []
    @State private var searchError: String?
    @State private var searching = false
    @State private var showProposals = false
    @State private var unreadProposals = 0
    @State private var selectedTopic: WorldTopic? = nil
    @State private var commentTarget: WorldPost? = nil
    @State private var myName: String = String(localized: "나")
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
                postStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: vm.category)
        .animation(.easeInOut(duration: 0.18), value: vm.sort)
        .task {
            await vm.loadIfNeeded()
            await refreshMyName()
            await refreshProposalBadge()
        }
        .task(id: vm.category) { await loadScoreFeed(reset: true) }
        // Reflect profile edits made in My Page without an app restart (BUG-008).
        .onReceive(NotificationCenter.default.publisher(for: .scoorUserProfileDidChange)) { _ in
            Task { await refreshMyName() }
        }
        .task(id: topicSearch) {
            guard !topicSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let world = appServices.worldService else { searchedTopics = []; searching = false; searchError = nil; return }
            searching = true
            do {
                try await Task.sleep(for: .milliseconds(350))
                let rows = try await world.searchTopics(topicSearch)
                try Task.checkCancellation()
                searchedTopics = rows; searchError = nil; searching = false
            } catch is CancellationError { } catch { searchError = error.localizedDescription; searching = false }
        }
        .sheet(isPresented: $showProposals, onDismiss: {
            Task { await vm.refresh(); await refreshProposalBadge() }
        }) {
            if let world = appServices.worldService {
                TopicProposalsView(service: world, moderation: appServices.moderationService, social: socialService)
            }
        }
        .sheet(item: $selectedTopic, onDismiss: { Task { await vm.refresh(); await loadScoreFeed(reset: true) } }) { topic in
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
            myName = user.username.isEmpty ? String(localized: "나") : user.username
        }
    }

    private func refreshProposalBadge() async {
        guard let world = appServices.worldService else { return }
        if let notices = try? await world.proposalNotifications() {
            unreadProposals = notices.filter { $0.readAt == nil }.count
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
            if vm.usesPreviewData {
                statusDot.padding(.leading, 2)
            }

            Spacer()
            if appServices.worldService != nil {
                Button { showProposals = true } label: {
                    Label(unreadProposals > 0 ? String(localized: "토픽 제안 · \(unreadProposals)") : String(localized: "토픽 제안"), systemImage: "plus.bubble")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ScoorPalette.accent)
                }.accessibilityIdentifier("world-proposals")
            }

            if vm.topicsAreLive {
                Text("토픽 \(vm.topics.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .monospacedDigit()
            } else if vm.usesPreviewData {
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
                Text(LocalizedStringKey(mode.rawValue))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

    @ViewBuilder
    private var loadedStream: some View {
        if appServices.worldService != nil { liveTopicList } else { seededPostStream }
    }

    /// Topics remain discoverable above the public score-and-reason stream.
    private var liveTopicList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                WorldTrendingRow(topics: vm.topics,
                                 onSelect: { selectedTopic = $0 })
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                Divider().background(ScoorPalette.hairline)

                WorldCategoryFilter(selected: $vm.category)
                    .padding(.vertical, 18)
                    .accessibilityIdentifier("world-category-menu")
                TextField("토픽 검색", text: $topicSearch)
                    .textFieldStyle(.roundedBorder).padding(.horizontal, 18).padding(.bottom, 12)
                    .accessibilityIdentifier("world-topic-search")
                if searching { ProgressView().padding() }
                if let searchError { Text(searchError).font(.caption).foregroundStyle(.red).padding() }
                if topicSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ForEach(liveScores) { row in
                        liveScoreCard(row)
                        Divider().background(ScoorPalette.hairline)
                    }
                    if scoreFeedLoading { ProgressView().padding(24) }
                    if let scoreFeedError {
                        Text(scoreFeedError).font(.caption).foregroundStyle(.red).padding()
                        Button("다시 시도") { Task { await loadScoreFeed(reset: liveScores.isEmpty) } }.padding()
                    } else if !scoreFeedLoading && liveScores.isEmpty {
                        emptyState
                    }
                    if scoreFeedHasMore && !scoreFeedLoading && !liveScores.isEmpty {
                        Button("점수 더 보기") { Task { await loadScoreFeed(reset: false) } }.padding()
                    }
                } else {
                    ForEach(searchedTopics.filter { vm.category == nil || $0.category == vm.category }) { topic in
                        WorldTopicListRow(topic: topic, onSelect: { selectedTopic = topic })
                        Divider().background(ScoorPalette.hairline)
                    }
                    if searchedTopics.isEmpty && !searching && searchError == nil {
                        Text("검색 결과가 없어요. 새 토픽을 제안해 보세요.").font(.subheadline).padding(24)
                    }
                }
                if let error = vm.transientError { Text(error).font(.caption).foregroundStyle(.red).padding() }
                bottomSpacer
            }
        }
        .refreshable { await vm.refresh(); await loadScoreFeed(reset: true) }
    }

    @MainActor
    private func loadScoreFeed(reset: Bool) async {
        guard let world = appServices.worldService else { return }
        if !reset && (scoreFeedLoading || !scoreFeedHasMore) { return }
        if reset {
            scoreFeedGeneration = UUID()
            liveScores = []
            scoreFeedHasMore = true
        }
        let generation = scoreFeedGeneration
        scoreFeedLoading = true
        scoreFeedError = nil
        defer { if generation == scoreFeedGeneration { scoreFeedLoading = false } }
        do {
            let rows = try await world.scoreFeed(category: vm.category, offset: liveScores.count)
            try Task.checkCancellation()
            guard generation == scoreFeedGeneration else { return }
            let existing = Set(liveScores.map(\.id))
            liveScores.append(contentsOf: rows.filter { !existing.contains($0.id) })
            scoreFeedHasMore = rows.count == 20
        } catch is CancellationError { }
        catch {
            guard generation == scoreFeedGeneration else { return }
            scoreFeedError = String(localized: "점수를 불러오지 못했어요. 다시 시도해 주세요.")
        }
    }

    private func liveScoreCard(_ row: WorldScoreFeedRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(row.reaction.isAnonymous ? "?" : String(row.reaction.identity.name.prefix(1)))
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(ScoorPalette.bgRaised, in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(row.reaction.identity.name).font(ScoorType.name)
                    Text(row.reaction.createdAt, style: .relative)
                        .font(ScoorType.meta).foregroundStyle(ScoorPalette.inkTertiary)
                }
                Button {
                    Task {
                        do { selectedTopic = try await appServices.worldService?.topic(id: row.topic.id) }
                        catch { scoreFeedError = String(localized: "토픽을 열지 못했어요. 다시 시도해 주세요.") }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.topic.categoryLabel).font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ScoorPalette.accent)
                        Text("\(row.topic.coverEmoji ?? "") \(row.topic.title)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ScoorPalette.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
                if let reason = row.reaction.comment, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(reason).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ScoreValueView(score: row.reaction.value,
                           font: .system(size: 40, weight: .heavy, design: .rounded),
                           color: ScoreTone.from(score: row.reaction.value).primary,
                           italic: true, logoHeight: 28, logoVariant: .white)
                .accessibilityLabel("점수 \(row.reaction.value)")
        }
        .foregroundStyle(ScoorPalette.inkPrimary)
        .padding(.horizontal, 18).padding(.vertical, 14)
        .accessibilityIdentifier("world-score-\(row.id)")
    }

    private var topicEmptyState: some View {
        VStack(spacing: 8) {
            Text("이 카테고리엔 아직 토픽이 없어요.")
                .accessibilityIdentifier("world-topic-empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text("매일 새 토픽이 올라옵니다.")
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var seededPostStream: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                WorldTrendingRow(topics: vm.topics,
                                 onSelect: { selectedTopic = $0 })
                    .padding(.top, 14)
                    .padding(.bottom, 14)

                Divider().background(ScoorPalette.hairline)

                if vm.usesPreviewData { PreviewContentBanner().padding(.vertical, 8) }
                WorldCategoryFilter(selected: $vm.category)
                    .padding(.vertical, 18)
                    .accessibilityIdentifier("world-category-menu")
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
            Text("아직 이 토픽에 대한 이야기가 없어요")
                .accessibilityIdentifier("world-post-empty")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text("토픽에 대한 점수와 의견이 이곳에 모여요")
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var bottomSpacer: some View { Color.clear.frame(height: 24) }
}

#Preview {
    WorldView(socialService: MockSocialService())
        .environmentObject(AppServices())
}
