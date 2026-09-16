//
//  CommunityGuidelinesSheet.swift
//  Scoor
//
//  커뮤니티 가이드라인 안내 (spec-13 §9, App Store Guideline 1.2).
//
//  안내용 화면. 콘텐츠 이용허락과 커뮤니티 규칙은 가입 시 이용약관으로 동의받는다.
//

import SwiftUI

struct CommunityGuidelinesSheet: View {

    @Environment(\.dismiss) private var dismiss


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(LegalPolicy.text("Scoor는 감정을 점수로 나누는 곳이에요.\n서로의 하루를 존중해 주세요.", "Share your day respectfully."))
                        .font(.title3.weight(.semibold))
                        .padding(.bottom, 4)

                    rule("🚫", LegalPolicy.text("괴롭힘·혐오 표현 금지", "No harassment or hate"),
                         LegalPolicy.text("특정인이나 집단을 향한 모욕, 차별, 위협은 삭제되고 계정이 제한될 수 있어요.", "Abuse, discrimination and threats may result in removal and account restrictions."))
                    rule("🔒", LegalPolicy.text("타인의 개인정보 게시 금지", "Respect other people’s privacy"),
                         LegalPolicy.text("실명, 연락처, 주소 등을 다른 사람 동의 없이 올릴 수 없어요.", "Do not post someone else’s private details without permission."))
                    rule("📣", LegalPolicy.text("스팸·광고 금지", "No spam or advertising"),
                         LegalPolicy.text("반복 게시나 홍보 목적의 글은 삭제됩니다.", "Repetitive or promotional posts may be removed."))
                    rule("🫂", LegalPolicy.text("위태로운 순간에는", "Keep the community safe"),
                         LegalPolicy.text("자해나 자살을 부추기는 내용은 금지예요. 힘든 사람을 발견하면 신고해 주세요 — 처벌이 아니라 도움으로 연결됩니다.", "Content encouraging self-harm or suicide is prohibited. Report harmful content; reports are not an emergency service."))
                    rule("👀", LegalPolicy.text("신고와 차단", "Report and block"),
                         LegalPolicy.text("불편한 글은 언제든 신고하거나 그 사용자를 차단할 수 있어요. 신고를 검토하고 필요한 조치를 취합니다.", "You can report content and block users. We review reports and take appropriate action."))

                }
                .padding(20)
            }
            .navigationTitle(LegalPolicy.text("커뮤니티 가이드라인", "Community guidelines"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button(LegalPolicy.text("확인", "Done")) {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)

                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
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

}
