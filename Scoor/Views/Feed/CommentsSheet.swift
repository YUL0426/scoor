//
//  CommentsSheet.swift
//  Scoor
//
//  댓글 시트 — 피드/월드 글 공통.
//  - 작성 / 수정 / 삭제([S4] 댓글 기능 완료 조건)
//  - 내 댓글만 수정·삭제 메뉴 노출
//  - 변경 시 onChange로 상위 카운트 동기화
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct CommentsSheet: View {

    @Environment(\.dismiss) private var dismiss

    let postId: UUID
    /// 헤더에 보여줄 원문 미리보기(선택).
    var headerPreview: String? = nil
    let service: SocialServiceProtocol
    var currentUserName: String = "나"
    var currentUserSeed: Int = 1
    /// 댓글 추가/수정/삭제 후 호출 — 상위(피드)에서 카운트 갱신.
    var onChange: () -> Void = {}

    @State private var comments: [SocialComment] = []
    @State private var phase: LoadPhase = .loading
    @State private var draft: String = ""
    @State private var editingId: UUID? = nil
    @State private var errorMessage: String? = nil
    @FocusState private var inputFocused: Bool

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().background(ScoorPalette.hairline)

                content

                Divider().background(ScoorPalette.hairline)
                inputBar
            }
        }
        .environment(\.colorScheme, .dark)
        .task { await reload() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text("댓글")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                if !comments.isEmpty {
                    Text("\(comments.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ScoorPalette.accent)
                        .monospacedDigit()
                }
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
            }
            if let preview = headerPreview, !preview.isEmpty {
                Text(preview)
                    .font(.system(size: 12.5))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading, .idle:
            VStack { Spacer(); ProgressView().tint(ScoorPalette.inkSecondary); Spacer() }
                .frame(maxWidth: .infinity)
        case .empty:
            emptyState
        case .error(let msg):
            VStack(spacing: 10) {
                Spacer()
                Text("불러오지 못했어요").font(.system(size: 14, weight: .semibold)).foregroundStyle(ScoorPalette.inkSecondary)
                Text(msg).font(.system(size: 12)).foregroundStyle(ScoorPalette.inkTertiary)
                Button("다시 시도") { Task { await reload() } }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ScoorPalette.accent)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        case .loaded:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(comments) { comment in
                        commentRow(comment)
                        Divider().background(ScoorPalette.hairlineSoft)
                    }
                    Color.clear.frame(height: 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "bubble.left")
                .font(.system(size: 30))
                .foregroundStyle(ScoorPalette.inkTertiary)
            Text("아직 댓글이 없어요.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
            Text("첫 댓글을 남겨보세요.")
                .font(.system(size: 12))
                .foregroundStyle(ScoorPalette.inkTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func commentRow(_ comment: SocialComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatar(seed: comment.authorSeed,
                   initial: String(comment.authorName.prefix(1)).uppercased())
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.authorName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Text("·").foregroundStyle(ScoorPalette.inkTertiary)
                    Text(RelativeTime.short(from: comment.createdAt))
                        .font(.system(size: 11))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                    if comment.isEdited {
                        Text("· 수정됨")
                            .font(.system(size: 11))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                    }
                    Spacer()
                    if comment.isMine {
                        Menu {
                            Button { beginEdit(comment) } label: { Label("수정", systemImage: "pencil") }
                            Button(role: .destructive) {
                                Task { await delete(comment) }
                            } label: { Label("삭제", systemImage: "trash") }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ScoorPalette.inkTertiary)
                                .frame(width: 28, height: 24)
                                .contentShape(Rectangle())
                        }
                    }
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(editingId == comment.id ? Color.white.opacity(0.04) : Color.clear)
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
            Circle().fill(palette[idx]).frame(width: 32, height: 32)
            Text(initial).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            if editingId != nil {
                HStack(spacing: 6) {
                    Image(systemName: "pencil").font(.system(size: 11, weight: .bold))
                    Text("댓글 수정 중")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button("취소") { cancelEdit() }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
                .foregroundStyle(ScoorPalette.accent)
                .padding(.horizontal, 4)
            }
            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                TextField("댓글 추가…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14.5))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ScoorPalette.bgRaised))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ScoorPalette.hairline, lineWidth: 0.6))

                Button { Task { await submit() } } label: {
                    Image(systemName: editingId == nil ? "arrow.up" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(canSubmit ? ScoorPalette.accent : ScoorPalette.inkTertiary.opacity(0.4)))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func reload() async {
        let list = await service.comments(for: postId)
        comments = list
        phase = list.isEmpty ? .empty : .loaded
    }

    private func submit() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        errorMessage = nil
        haptic()
        do {
            if let editId = editingId {
                try await service.editComment(id: editId, newText: text)
            } else {
                try await service.addComment(postId: postId, text: text,
                                             authorName: currentUserName, authorSeed: currentUserSeed)
            }
            draft = ""
            editingId = nil
            inputFocused = false
            await reload()
            onChange()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "처리에 실패했어요."
        }
    }

    private func beginEdit(_ comment: SocialComment) {
        editingId = comment.id
        draft = comment.text
        inputFocused = true
    }

    private func cancelEdit() {
        editingId = nil
        draft = ""
        inputFocused = false
    }

    private func delete(_ comment: SocialComment) async {
        haptic()
        do {
            try await service.deleteComment(id: comment.id)
            if editingId == comment.id { cancelEdit() }
            await reload()
            onChange()
        } catch {
            errorMessage = "삭제에 실패했어요."
        }
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
