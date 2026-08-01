//
//  CommunityGuidelinesSheet.swift
//  Scoor
//
//  커뮤니티 가이드라인 동의 (spec-13 §9, App Store Guideline 1.2).
//
//  첫 게시 직전에 한 번만 띄운다 — 가입 시점이 아니라. 동의는 그것이 규율하는
//  행동 바로 옆에 있어야 읽히고, 온보딩에 밀어넣으면 아무도 읽지 않는다.
//

import SwiftUI

struct CommunityGuidelinesSheet: View {

    @Environment(\.dismiss) private var dismiss

    let service: RemoteModerationService?
    /// 동의 완료 후 원래 하려던 게시 동작을 이어서 실행한다.
    var onAccepted: () -> Void

    @State private var isSubmitting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Scoor는 감정을 점수로 나누는 곳이에요.\n서로의 하루를 존중해 주세요.")
                        .font(.title3.weight(.semibold))
                        .padding(.bottom, 4)

                    rule("🚫", "괴롭힘·혐오 표현 금지",
                         "특정인이나 집단을 향한 모욕, 차별, 위협은 삭제되고 계정이 제한될 수 있어요.")
                    rule("🔒", "타인의 개인정보 게시 금지",
                         "실명, 연락처, 주소 등을 다른 사람 동의 없이 올릴 수 없어요.")
                    rule("📣", "스팸·광고 금지",
                         "반복 게시나 홍보 목적의 글은 삭제됩니다.")
                    rule("🫂", "위태로운 순간에는",
                         "자해나 자살을 부추기는 내용은 금지예요. 힘든 사람을 발견하면 신고해 주세요 — 처벌이 아니라 도움으로 연결됩니다.")
                    rule("👀", "신고와 차단",
                         "불편한 글은 언제든 신고하거나 그 사용자를 차단할 수 있어요. 신고는 24시간 안에 검토됩니다.")

                    if let errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .navigationTitle("커뮤니티 가이드라인")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        accept()
                    } label: {
                        Text(isSubmitting ? "확인 중…" : "동의하고 계속")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting)

                    Button("취소") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func rule(_ glyph: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(glyph).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func accept() {
        isSubmitting = true
        errorText = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await service?.acceptGuidelines()
                onAccepted()
                dismiss()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }
}
