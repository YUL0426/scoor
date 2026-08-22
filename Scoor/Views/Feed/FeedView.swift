//
//  FeedView.swift
//  Scoor
//
//  Toss Community 톤의 텍스트 우선 피드.
//  - 데이터: SocialService 기반(FeedViewModel) — 좋아요/댓글 영속, 페이지네이션, 새로고침
//  - 상단 sticky: 작은 헤더 + 탐색 진입 + 정렬 탭 + 필터 칩
//  - 본문: hairline divider로 구분된 flat 카드 스트림, 무한 스크롤
//  - 로딩/빈/에러 상태 처리
//

import SwiftUI

struct FeedView: View {

    @EnvironmentObject private var appServices: AppServices
    @StateObject private var vm: FeedViewModel

    private let socialService: SocialServiceProtocol
    private let feedService: RemoteFeedService?

    @State private var commentTarget: FeedEntry? = nil
    @State private var reportTarget: FeedEntry? = nil
    /// 신고한 글은 검토 전에도 신고자 화면에서 즉시 사라진다 (World와 같은 규칙).
    @State private var hiddenEntryIds: Set<UUID> = []
    @State private var showDiscover = false
    @State private var myName: String = "나"
    private let mySeed = 1

    init(socialService: SocialServiceProtocol, feedService: RemoteFeedService? = nil) {
        self.socialService = socialService
        self.feedService = feedService
        _vm = StateObject(wrappedValue: FeedViewModel(service: socialService, remote: feedService))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeader
                // 시드 경로에서만 남는 두 가지: "예시 콘텐츠" 배너와, 수치가
                // 전부 가짜인 펄스 티커. 서버 피드에서는 둘 다 거짓말이 된다.
                if !vm.isLive {
                    PreviewContentBanner()
                        .padding(.top, 4)
                    LivePulseView(pulses: MockFeed.pulses)
                        .padding(.top, 6)
                }
                sortTabs
                    .padding(.top, 10)
                Divider().background(ScoorPalette.hairlineSoft)
                MoodFilterView(selected: $vm.selectedMood)
                    .padding(.vertical, 10)
                Divider().background(ScoorPalette.hairline)

                feedStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: vm.selectedMood)
        .animation(.easeInOut(duration: 0.18), value: vm.sort)
        .task {
            await vm.loadIfNeeded()
            if let user = await appServices.userService.getCurrentUser() {
                myName = user.username.isEmpty ? "나" : user.username
            }
        }
        .sheet(item: $commentTarget) { entry in
            CommentsSheet(
                postId: entry.id,
                headerPreview: entry.message,
                service: socialService,
                remote: feedService,
                moderationService: appServices.moderationService,
                currentUserName: myName,
                currentUserSeed: mySeed,
                onChange: { Task { await vm.reloadOverlays() } }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $reportTarget) { entry in
            ReportSheet(
                targetType: .post,
                targetId: entry.id,
                authorId: entry.authorId,
                service: appServices.moderationService,
                onCompleted: { hiddenEntryIds.insert(entry.id) }
            )
        }
        .sheet(isPresented: $showDiscover) {
            DiscoverView(socialService: socialService)
        }
    }

    // MARK: - Top header

    private var topHeader: some View {
        HStack(spacing: 8) {
            Text("Feed")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(ScoorPalette.inkPrimary)
            statusDot.padding(.leading, 2)

            Spacer()

            if !vm.isLive {
            HStack(spacing: 6) {
                Text("오늘")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text(CompactCount.format(MockFeed.todayCount))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .monospacedDigit()
                Text("·").font(.system(size: 11)).foregroundStyle(ScoorPalette.inkTertiary)
                Text("평균 \(MockFeed.todayAverage)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ScoorPalette.accent)
                    .monospacedDigit()
            }
            }

            // 탐색(Discover)은 팔로우할 실사용자가 생기는 Phase 3 전까지 시드
            // 프로필만 보여준다. 나머지 화면이 실데이터로 바뀐 뒤에도 여기만
            // 가짜로 남으면, 배너 없이 조용히 가짜인 유일한 화면이 된다.
            if !vm.isLive {
            Button { showDiscover = true } label: {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .frame(width: 32, height: 32)
                    .background(ScoorPalette.bgRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("사용자 탐색")
            .accessibilityIdentifier("feed.discoverButton")
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
            ForEach(FeedSort.allCases) { mode in sortTab(mode) }
            Spacer()
        }
        .padding(.horizontal, 18)
    }

    private func sortTab(_ mode: FeedSort) -> some View {
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

    // MARK: - Feed stream

    @ViewBuilder
    private var feedStream: some View {
        switch vm.phase {
        case .idle, .loading:
            loadingState
        case .error(let msg):
            errorState(msg)
        case .empty:
            ScrollView { emptyState.padding(.top, 80) }.refreshable { await vm.refresh() }
        case .loaded:
            loadedStream
        }
    }

    private var loadedStream: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.visible.filter { !hiddenEntryIds.contains($0.id) }) { entry in
                    if let binding = vm.binding(for: entry.id) {
                        FeedCardView(
                            entry: binding,
                            onLikeToggle: { liked in vm.persistLike(entryId: entry.id, nowLiked: liked) },
                            onCommentTap: { commentTarget = entry },
                            onReportTap: appServices.moderationService == nil
                                ? nil
                                : { reportTarget = entry }
                        )
                        .onAppear { Task { await vm.loadMoreIfNeeded(currentItem: entry) } }
                        Divider().background(ScoorPalette.hairline)
                    }
                }

                if vm.visible.allSatisfy({ hiddenEntryIds.contains($0.id) }) {
                    emptyState.padding(.top, 60)
                }
                if vm.isLoadingMore { loadMoreSpinner }
                bottomSpacer
            }
        }
        .refreshable { await vm.refresh() }
    }

    private var loadingState: some View {
        VStack { Spacer(); ProgressView().tint(ScoorPalette.inkSecondary); Spacer() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "wifi.exclamationmark").font(.system(size: 32)).foregroundStyle(ScoorPalette.inkTertiary)
            Text("피드를 불러오지 못했어요").font(.system(size: 15, weight: .semibold)).foregroundStyle(ScoorPalette.inkSecondary)
            Text(msg).font(.system(size: 12)).foregroundStyle(ScoorPalette.inkTertiary)
            Button("다시 시도") { Task { await vm.load() } }
                .font(.system(size: 13, weight: .bold)).foregroundStyle(ScoorPalette.accent)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadMoreSpinner: some View {
        ProgressView().tint(ScoorPalette.inkTertiary).padding(.vertical, 18)
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

    private var bottomSpacer: some View { Color.clear.frame(height: 120) }
}

#Preview {
    FeedView(socialService: MockSocialService())
        .environmentObject(AppServices())
}
