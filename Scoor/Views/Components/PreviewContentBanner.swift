//
//  PreviewContentBanner.swift
//  Scoor
//
//  커뮤니티(피드/월드/탐색) 화면 상단의 정직성 고지 (P0-1).
//  소셜 레이어는 아직 백엔드가 없어 시드(예시) 콘텐츠로 동작한다 — 사용자가
//  예시 게시물을 실존 인물의 실시간 글로 오인하지 않도록 명시적으로 라벨링한다.
//  온라인 서비스가 붙으면 이 배너 호출부만 제거하면 된다.
//

import SwiftUI

struct PreviewContentBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ScoorPalette.accent)
            Text("미리보기 — 예시 콘텐츠입니다. 실제 커뮤니티는 온라인 서비스 출시와 함께 열려요.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(ScoorPalette.inkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ScoorPalette.bgRaised.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ScoorPalette.accent.opacity(0.25), lineWidth: 0.5)
        )
        .padding(.horizontal, 18)
        .accessibilityIdentifier("preview-content-banner")
    }
}

#Preview {
    ZStack {
        ScoorPalette.bgBase.ignoresSafeArea()
        PreviewContentBanner()
    }
    .environment(\.colorScheme, .dark)
}
