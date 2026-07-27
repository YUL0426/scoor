//
//  BlockedUsersView.swift
//  Scoor
//
//  Manage blocked users (spec-13 C7, §9).
//
//  App Store Guideline 1.2 asks for the ability to block abusive users; being able
//  to *undo* a block belongs with it, otherwise the only way back is support mail.
//  Unblocking is optimistic — the row leaves immediately and comes back if the
//  server refused, because a list that lags makes the user tap twice.
//

import SwiftUI

struct BlockedUsersView: View {

    let moderationService: RemoteModerationService?

    @State private var blocked: [BlockedUser] = []
    @State private var phase: Phase = .loading
    @State private var errorMessage: String?

    private enum Phase { case loading, loaded, failed }

    var body: some View {
        List {
            switch phase {
            case .loading:
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)

            case .failed:
                VStack(spacing: 12) {
                    Text(errorMessage ?? "목록을 불러올 수 없어요.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("다시 시도") { Task { await load() } }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.scoorRed)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .listRowBackground(Color.clear)

            case .loaded where blocked.isEmpty:
                VStack(spacing: 8) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("차단한 사용자가 없습니다")
                        .font(.system(size: 15, weight: .semibold))
                    Text("누군가를 차단하면 그 사람의 글과 댓글이 보이지 않습니다.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("blocked-users-empty")

            case .loaded:
                ForEach(blocked) { user in
                    HStack(spacing: 12) {
                        Text(user.profile?.avatarEmoji ?? "🙈")
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.username)
                                .font(.system(size: 15, weight: .semibold))
                            Text(Self.blockedAtText(user.createdAt))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("해제") { Task { await unblock(user) } }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.scoorRed)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("차단한 사용자")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    // MARK: - Actions

    private func load() async {
        guard let moderationService else {
            // No backend in this build: there is nothing to block against yet.
            blocked = []
            phase = .loaded
            return
        }
        phase = .loading
        do {
            blocked = try await moderationService.blockedUsers()
            phase = .loaded
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
            phase = .failed
        }
    }

    private func unblock(_ user: BlockedUser) async {
        guard let moderationService else { return }
        let previous = blocked
        blocked.removeAll { $0.id == user.id }
        do {
            try await moderationService.unblock(user.blockedId)
        } catch {
            blocked = previous
            errorMessage = "차단 해제에 실패했어요. 다시 시도해주세요."
        }
    }

    private static func blockedAtText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMd")
        return "\(f.string(from: date)) 차단"
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView(moderationService: nil)
    }
}
