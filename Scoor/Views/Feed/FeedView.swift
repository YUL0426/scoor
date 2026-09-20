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

    private let repostsOnly: Bool
    private let socialService: SocialServiceProtocol
    private let feedService: RemoteFeedService?
    var onRequestScoreSheet: (() -> Void)?
    var onOpenProfile: () -> Void
    @State private var avatarURL: URL?

    @State private var commentTarget: FeedEntry? = nil
    @State private var reportTarget: FeedEntry? = nil
    /// 신고한 글은 검토 전에도 신고자 화면에서 즉시 사라진다 (World와 같은 규칙).
    @State private var hiddenEntryIds: Set<UUID> = []
    @AppStorage("feed.interestMood") private var interestMood = Mood.work.rawValue
    @State private var interestActive = false
    @State private var showInterests = false
    @State private var editingInterests = false
    @State private var draftInterest = Mood.work.rawValue
    @State private var showDiscover = false
    @State private var myName: String = String(localized: "나")
    private let mySeed = 1

    init(socialService: SocialServiceProtocol, feedService: RemoteFeedService? = nil, onRequestScoreSheet: (() -> Void)? = nil, onOpenProfile: @escaping () -> Void = {}, repostsOnly: Bool = false) {
        self.repostsOnly = repostsOnly
        self.onOpenProfile = onOpenProfile
        self.onRequestScoreSheet = onRequestScoreSheet
        self.socialService = socialService
        self.feedService = feedService
        _vm = StateObject(wrappedValue: FeedViewModel(service: socialService, remote: feedService, repostsOnly: repostsOnly))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                if !repostsOnly {
                    topHeader
                    // 시드 경로에서만 남는 두 가지: "예시 콘텐츠" 배너와, 수치가
                    // 전부 가짜인 펄스 티커. 서버 피드에서는 둘 다 거짓말이 된다.
                    if vm.usesPreviewData {
                        PreviewContentBanner()
                            .padding(.top, 4)
                    }
                    sortTabs
                        .padding(.top, 10)
                    Divider().background(ScoorPalette.hairlineSoft)

                }
                feedStream
            }
        }
        .environment(\.colorScheme, .dark)
        .animation(.easeInOut(duration: 0.18), value: vm.selectedMood)
        .animation(.easeInOut(duration: 0.18), value: vm.sort)
        .task {
            await vm.loadIfNeeded()
            if let user = await appServices.userService.getCurrentUser() {
                myName = user.username.isEmpty ? String(localized: "나") : user.username
                avatarURL = user.avatarURL
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoorHomeFeedDidChange)) { _ in
            Task { await vm.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scoorRepostsDidChange)) { _ in
            Task { if repostsOnly { await vm.refresh() } else { await vm.reloadOverlays() } }
        }
        .alert("저장 실패", isPresented: Binding(get: { vm.transientError != nil }, set: { if !$0 { vm.transientError = nil } })) {
            Button("확인") { vm.transientError = nil }
        } message: { Text(vm.transientError ?? "") }
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
        ZStack {
            ScoorLogo(size: 44, variant: .white)
                .accessibilityIdentifier("home-centered-logo")
            HStack {
                Button(action: onOpenProfile) {
                    ProfileAvatarView(imageURL: avatarURL, size: 32)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("내 프로필")
                .accessibilityIdentifier("home-profile-button")
                Spacer()
                Button { showDiscover = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("검색")
                .accessibilityIdentifier("home-search-button")
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Sort tabs

    private var sortTabs: some View {
        HStack(spacing: 0) {
            ForEach(FeedSort.allCases) { mode in sortTab(mode) }
            Button {
                interestActive = true
                vm.selectedMood = Mood(rawValue: interestMood)
                draftInterest = interestMood
                editingInterests = false
                showInterests = true
            } label: {
                VStack(spacing: 6) {
                    Text("관심").font(.system(size: 14, weight: .semibold))
                    Rectangle().fill(interestActive ? ScoorPalette.accent : .clear).frame(height: 2)
                }
                .foregroundStyle(interestActive ? ScoorPalette.inkPrimary : ScoorPalette.inkTertiary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed-interests-tab")
        }
        .padding(.horizontal, 18)
        .sheet(isPresented: $showInterests) {
            NavigationStack {
                List(editingInterests ? Mood.allCases : [Mood(rawValue: interestMood) ?? .work]) { mood in
                    Button {
                        if editingInterests { draftInterest = mood.rawValue }
                    } label: {
                        HStack {
                            Text(mood.label)
                            Spacer()
                            if draftInterest == mood.rawValue { Image(systemName: "checkmark") }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(editingInterests ? String(localized: "취소") : String(localized: "편집")) {
                            draftInterest = interestMood
                            editingInterests.toggle()
                        }
                        .accessibilityIdentifier("interests-edit-button")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("완료") {
                            interestMood = draftInterest
                            vm.selectedMood = Mood(rawValue: draftInterest)
                            showInterests = false
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
            .presentationDetents([.medium, .large])
        }
    }

    private func sortTab(_ mode: FeedSort) -> some View {
        Button { interestActive = false; vm.selectedMood = nil; vm.sort = mode } label: {
            VStack(spacing: 6) {
                Text(LocalizedStringKey(mode.rawValue))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .font(.system(size: 14, weight: (!interestActive && vm.sort == mode) ? .bold : .medium))
                    .foregroundStyle((!interestActive && vm.sort == mode) ? ScoorPalette.inkPrimary : ScoorPalette.inkTertiary)
                Rectangle()
                    .fill((!interestActive && vm.sort == mode) ? ScoorPalette.accent : Color.clear)
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
            if repostsOnly { emptyState } else {
                ScrollView { emptyState.padding(.top, 80) }.refreshable { await vm.refresh() }
            }
        case .loaded:
            loadedStream
        }
    }

    @ViewBuilder
    private var loadedStream: some View {
        if repostsOnly { feedRows } else {
            ScrollView { feedRows }.refreshable { await vm.refresh() }
        }
    }

    private var feedRows: some View {
        LazyVStack(spacing: 0) {
            ForEach(vm.visible.filter { !hiddenEntryIds.contains($0.id) }) { entry in
                if let binding = vm.binding(for: entry.id) {
                    FeedCardView(
                        entry: binding,
                        onLikeToggle: { liked in vm.persistLike(entryId: entry.id, nowLiked: liked) },
                        onCommentTap: { commentTarget = entry },
                        onReportTap: appServices.moderationService == nil
                            ? nil
                            : { reportTarget = entry },
                        onRepostTap: feedService == nil ? nil : { vm.toggleRepost(entryId: entry.id) },
                        repostPending: vm.pendingReposts.contains(entry.id)
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
            Text(repostsOnly ? String(localized: "아직 리포스트한 글이 없어요") : String(localized: "아직 나눠진 하루가 없어요"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text(repostsOnly ? String(localized: "홈에서 마음에 드는 글을 리포스트해보세요") : String(localized: "오늘의 점수와 한 줄로 이야기를 시작해보세요"))
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var bottomSpacer: some View { Color.clear.frame(height: 24) }
}

#Preview {
    FeedView(socialService: MockSocialService())
        .environmentObject(AppServices())
}
