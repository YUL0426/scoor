//
//  MyScoorsView.swift
//  Scoor
//
//  "My Scoors" 전체 이력 화면 — 사용자가 점수 매긴 토픽/이슈/엔티티 전체 목록.
//  - 토픽 제목 · 내 점수 · 내 사유 · 매긴 날짜를 한 행으로.
//  - 검색(searchable)으로 토픽/사유 필터링 — 향후 정렬/필터 확장 지점.
//

import SwiftUI

struct MyScoorsView: View {
    let entries: [MyScoorEntry]
    @State private var query: String = ""

    private var filtered: [MyScoorEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return entries }
        return entries.filter {
            $0.topicTitle.lowercased().contains(trimmed)
                || ($0.reason?.lowercased().contains(trimmed) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            if filtered.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { entry in
                        MyScoorRow(entry: entry)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                        Divider()
                            .background(ScoorPalette.hairline)
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(DesignTokens.backgroundColor)
        .environment(\.colorScheme, .dark)
        .navigationTitle("My Scoors")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "토픽 또는 사유 검색")
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: isSearching ? "magnifyingglass" : "globe.asia.australia.fill")
                .font(.system(size: 26))
                .foregroundStyle(DesignTokens.textSecondary.opacity(0.6))
            if isSearching {
                Text("결과가 없어요")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
            } else {
                Text("아직 점수 매긴 토픽이 없어요")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignTokens.textPrimary)
                Text("World에서 이슈에 점수를 매기면 여기에 모여요")
                    .font(.system(size: 13))
                    .foregroundStyle(DesignTokens.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 80)
    }
}

#Preview {
    NavigationStack {
        MyScoorsView(entries: [
            MyScoorEntry(id: "1", topicTitle: "Apple WWDC", targetId: "match",
                         score: 82, reason: "AI was weaker than expected", createdAt: Date()),
            MyScoorEntry(id: "2", topicTitle: "한국 대선", targetId: "match",
                         score: 74, reason: "정책 방향이 불분명하다", createdAt: Date()),
            MyScoorEntry(id: "3", topicTitle: "토트넘 vs 아스널", targetId: "team-TOT",
                         score: 100, reason: "완벽한 경기였다", createdAt: Date())
        ])
    }
    .environment(\.colorScheme, .dark)
}
