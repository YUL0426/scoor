//
//  DiscoverView.swift
//  Scoor
//
//  사용자 탐색 — 사람과 콘텐츠를 발견하는 화면([S4] 사용자 탐색 기능).
//  완료 조건: 인기 사용자 / 추천 사용자 / 추천 콘텐츠.
//  - 팔로우 토글(낙관적 + 로컬 영속)
//  - 검색 필터, 로딩/빈/에러 상태
//

import SwiftUI

struct DiscoverView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm: DiscoverViewModel

    init(socialService: SocialServiceProtocol) {
        _vm = StateObject(wrappedValue: DiscoverViewModel(service: socialService))
    }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                PreviewContentBanner()
                    .padding(.bottom, 8)
                searchBar
                Divider().background(ScoorPalette.hairline)
                content
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await vm.loadIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("탐색")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(ScoorPalette.inkPrimary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .frame(width: 30, height: 30)
                    .background(ScoorPalette.bgRaised)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("discover.closeButton")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ScoorPalette.inkTertiary)
            TextField("사람 검색", text: $vm.query)
                .font(.system(size: 14))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .autocorrectionDisabled()
            if !vm.query.isEmpty {
                Button { vm.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ScoorPalette.bgRaised))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ScoorPalette.hairline, lineWidth: 0.6))
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch vm.phase {
        case .idle, .loading:
            VStack { Spacer(); ProgressView().tint(ScoorPalette.inkSecondary); Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            VStack(spacing: 10) {
                Spacer()
                Text("불러오지 못했어요").font(.system(size: 15, weight: .semibold)).foregroundStyle(ScoorPalette.inkSecondary)
                Text(msg).font(.system(size: 12)).foregroundStyle(ScoorPalette.inkTertiary)
                Button("다시 시도") { Task { await vm.load() } }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(ScoorPalette.accent)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            VStack(spacing: 8) {
                Spacer()
                Text("표시할 사람이 없어요").font(.system(size: 14, weight: .medium)).foregroundStyle(ScoorPalette.inkSecondary)
                Spacer()
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            loadedContent
        }
    }

    private var loadedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    recommendedContentSection
                }

                sectionHeader("인기 사용자", systemImage: "flame.fill")
                ForEach(vm.filteredPopular.prefix(8)) { user in
                    userRow(user)
                    Divider().background(ScoorPalette.hairlineSoft).padding(.leading, 64)
                }

                sectionHeader("추천 사용자", systemImage: "sparkles")
                if vm.filteredRecommended.isEmpty {
                    Text("추천할 새 사용자가 없어요. 이미 다 팔로우 중!")
                        .font(.system(size: 12.5))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                        .padding(.horizontal, 18).padding(.vertical, 14)
                } else {
                    ForEach(vm.filteredRecommended.prefix(8)) { user in
                        userRow(user)
                        Divider().background(ScoorPalette.hairlineSoft).padding(.leading, 64)
                    }
                }

                Color.clear.frame(height: 40)
            }
        }
        .refreshable { await vm.refresh() }
    }

    // MARK: - Recommended content

    private var recommendedContentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("추천 콘텐츠", systemImage: "globe")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.data.recommendedContent) { content in
                        contentCard(content)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
            }
        }
    }

    private func contentCard(_ content: RecommendedContent) -> some View {
        let tone = ScoreTone.from(score: content.score)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(content.glyph).font(.system(size: 26))
                Spacer()
                Text("\(content.score)")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(tone.primary)
                    .monospacedDigit()
            }
            Text(content.title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ScoorPalette.inkPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(content.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ScoorPalette.inkTertiary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 180, height: 130, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ScoorPalette.bgRaised))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ScoorPalette.hairline, lineWidth: 0.6))
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ScoorPalette.accent)
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(ScoorPalette.inkPrimary)
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    // MARK: - User row

    private func userRow(_ user: DiscoverUser) -> some View {
        let tone = ScoreTone.from(score: user.averageScore)
        return HStack(spacing: 12) {
            avatar(seed: user.identity.avatarSeed,
                   initial: String(user.identity.name.prefix(1)).uppercased())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.identity.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Text(user.regionFlag).font(.system(size: 11))
                    Text("평균 \(user.averageScore)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(tone.primary)
                        .monospacedDigit()
                }
                Text(user.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                    .lineLimit(1)
                Text("팔로워 \(CompactCount.format(user.followers)) · 글 \(user.postCount)")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .monospacedDigit()
            }
            Spacer()
            followButton(user)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func followButton(_ user: DiscoverUser) -> some View {
        Button { vm.toggleFollow(user) } label: {
            Text(user.isFollowing ? "팔로잉" : "팔로우")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(user.isFollowing ? ScoorPalette.inkSecondary : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(user.isFollowing ? Color.white.opacity(0.06) : ScoorPalette.accent)
                )
                .overlay(
                    Capsule().stroke(user.isFollowing ? ScoorPalette.hairline : Color.clear, lineWidth: 0.6)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("discover.follow.\(user.identity.name)")
    }

    private func avatar(seed: Int, initial: String) -> some View {
        let palette: [Color] = [
            Color(red: 0.43, green: 0.49, blue: 0.66), Color(red: 0.66, green: 0.45, blue: 0.51),
            Color(red: 0.51, green: 0.57, blue: 0.50), Color(red: 0.71, green: 0.55, blue: 0.39),
            Color(red: 0.50, green: 0.47, blue: 0.63), Color(red: 0.42, green: 0.55, blue: 0.55),
            Color(red: 0.62, green: 0.58, blue: 0.42), Color(red: 0.58, green: 0.49, blue: 0.55),
            Color(red: 0.45, green: 0.52, blue: 0.59)
        ]
        let idx = max(0, min(palette.count - 1, seed - 1))
        return ZStack {
            Circle().fill(palette[idx]).frame(width: 40, height: 40)
            Text(initial).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
        }
    }
}

#Preview {
    DiscoverView(socialService: MockSocialService())
}
