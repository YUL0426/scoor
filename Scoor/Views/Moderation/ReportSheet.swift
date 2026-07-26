//
//  ReportSheet.swift
//  Scoor
//
//  신고 시트 (spec-13 §9, App Store Guideline 1.2).
//
//  UGC를 게시할 수 있는 화면이라면 어디서든 이 시트에 닿을 수 있어야 한다.
//  감정 기록 앱이라는 특성상 "자해/자살 위험" 사유는 처벌이 아니라 도움으로
//  연결되어야 해서, 그 항목을 고르면 신고와 별개로 상담 리소스를 함께 보여준다.
//

import SwiftUI

struct ReportSheet: View {

    @Environment(\.dismiss) private var dismiss

    let targetType: RemoteModerationService.ReportTarget
    let targetId: UUID
    /// 신고 대상 작성자 — 차단까지 함께 제안하기 위해 필요. 익명 글이면 nil.
    let authorId: UUID?
    let service: RemoteModerationService?

    /// 신고 완료 후 상위 화면이 목록에서 해당 항목을 감추도록 알린다.
    var onCompleted: (() -> Void)?

    @State private var reason: RemoteModerationService.ReportReason = .spam
    @State private var detail = ""
    @State private var alsoBlock = false
    @State private var isSubmitting = false
    @State private var errorText: String?
    @State private var didSubmit = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(RemoteModerationService.ReportReason.allCases, id: \.self) { r in
                        Button {
                            reason = r
                        } label: {
                            HStack {
                                Text(r.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if reason == r {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                } header: {
                    Text("신고 사유")
                }

                if reason == .selfHarm {
                    Section {
                        SelfHarmResourceCard()
                    }
                }

                Section {
                    TextField("자세한 내용 (선택)", text: $detail, axis: .vertical)
                        .lineLimit(3...6)
                } footer: {
                    Text("신고는 24시간 안에 검토됩니다. 신고자 정보는 상대에게 공개되지 않습니다.")
                }

                if authorId != nil {
                    Section {
                        Toggle("이 사용자의 글 더 이상 보지 않기", isOn: $alsoBlock)
                    } footer: {
                        Text("차단하면 이 사용자의 반응이 즉시 보이지 않습니다. 상대에게는 알려지지 않습니다.")
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("신고하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "제출 중…" : "제출") { submit() }
                        .disabled(isSubmitting || didSubmit)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() {
        guard let service else {
            errorText = "서버에 연결되어 있지 않습니다."
            return
        }
        isSubmitting = true
        errorText = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await service.report(
                    targetType,
                    id: targetId,
                    reason: reason,
                    detail: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? nil : detail
                )
                if alsoBlock, let authorId {
                    try await service.block(authorId)
                }
                didSubmit = true
                onCompleted?()
                dismiss()
            } catch {
                errorText = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
            }
        }
    }
}

/// 자해/자살 관련 신고 시 노출되는 안내 (spec-13 §9).
///
/// 신고 흐름 안에 두는 이유: 이 사유를 고르는 사람은 남을 처벌하려는 게 아니라
/// 누군가를 걱정하는 경우가 대부분이다. 그 순간에 필요한 건 접수 확인이 아니라
/// 어디에 연락하면 되는지다.
struct SelfHarmResourceCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("도움을 받을 수 있어요", systemImage: "heart.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.pink)

            Text("자살예방 상담전화 **109** — 24시간, 무료")
                .font(.footnote)
            Text("정신건강 상담전화 **1577-0199**")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("당장 위험한 상황이라면 119에 연락해 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
