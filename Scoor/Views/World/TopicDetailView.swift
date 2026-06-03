//
//  TopicDetailView.swift
//  Scoor
//
//  World 탭에서 토픽 카드를 탭했을 때 띄우는 디테일 모달.
//  - 헤더(커버 + 토픽 + 소스/시간) → 글로벌 Scoor 게이지 → 국가별 비교 →
//    (스포츠일 때) 매치/팀/MVP 패널 → 최근 반응 리스트 → 하단 sticky CTA.
//  - “Score your reaction.” 가 메인 인터랙션.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct TopicDetailView: View {

    @Environment(\.dismiss) private var dismiss

    /// 토픽 자체는 상위에서 받아오고, 화면 내에서 globalScore 만 사용자 점수 반영해 갱신.
    @State var topic: WorldTopic
    @State private var selectedRegion: WorldRegion = .global
    @State private var showScoreSheet = false
    @State private var scoreTarget: ScoorTarget = .match
    @State private var mySubmissions: [ScoorTarget: Int] = [:]
    @State private var feedbackScore: Int? = nil

    private var detail: TopicDetail { MockWorld.detail(for: topic) }

    private var tone: ScoreTone { .from(score: topic.globalScore) }

    var body: some View {
        ZStack {
            ScoorPalette.bgBase.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    coverHeader
                    metaBlock
                    heatBadge
                    globalScoreSection
                    countrySection
                    if let sports = detail.sports {
                        sportsPanel(sports)
                    }
                    recentSection
                    Color.clear.frame(height: 140)
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomCTA
            }

            if let s = feedbackScore {
                feedbackOverlay(score: s)
                    .transition(.opacity)
            }
        }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showScoreSheet) {
            TopicScoreSheet(
                topic: topic,
                target: $scoreTarget,
                existing: mySubmissions[scoreTarget]
            ) { submitted in
                handleSubmission(score: submitted)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Top bar (close button overlay)

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.black.opacity(0.45)))
                    .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    // MARK: - Cover header

    private var coverHeader: some View {
        ZStack(alignment: .bottomLeading) {
            // 그라디언트 커버
            LinearGradient(
                colors: [
                    coverColor.opacity(0.85),
                    coverColor.opacity(0.35),
                    ScoorPalette.bgBase
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: 220)

            // 그림자 그라데이션 (텍스트 가독성)
            LinearGradient(
                colors: [.black.opacity(0), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 220)

            // 토픽 라벨
            HStack(alignment: .bottom, spacing: 10) {
                Text(topic.emoji)
                    .font(.system(size: 38))
                    .shadow(color: .black.opacity(0.35), radius: 8)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(topic.category.emoji).font(.system(size: 11))
                        Text(topic.category.label.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    Text(topic.title)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)
        }
    }

    private var coverColor: Color {
        Color(hue: detail.coverHue, saturation: 0.65, brightness: 0.7)
    }

    // MARK: - Meta block (source · time · summary)

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkTertiary)
                Text(detail.source)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ScoorPalette.inkSecondary)
                Text("·").font(.system(size: 11)).foregroundStyle(ScoorPalette.inkTertiary)
                Text(RelativeTime.short(from: topic.lastActivityAt) + " 전")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
            Text(detail.summary)
                .font(.system(size: 14.5, weight: .regular))
                .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.94))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 16)
    }

    private var heatBadge: some View {
        HStack {
            Text(topic.heat.label)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.4)
                .foregroundStyle(heatColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(heatColor.opacity(0.12)))
                .overlay(Capsule().stroke(heatColor.opacity(0.35), lineWidth: 0.6))
            Spacer()
            Text("\(CompactCount.format(detail.globalParticipants))명 참여")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ScoorPalette.inkTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var heatColor: Color {
        switch topic.heat {
        case .hot, .rising, .fresh: return ScoorPalette.accent
        case .falling:              return ScoorPalette.night
        case .calm:                 return ScoorPalette.inkSecondary
        }
    }

    // MARK: - Global Score Section

    private var globalScoreSection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("GLOBAL SCOOR")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ScoorPalette.inkSecondary)
                Spacer()
                deltaPill
            }
            .padding(.horizontal, 18)

            ScoorGauge(score: topic.globalScore, tone: tone)
                .frame(height: 180)
                .padding(.horizontal, 18)
        }
        .padding(.top, 22)
    }

    private var deltaPill: some View {
        let d = topic.scoreDelta
        let isUp = d > 0
        let isFlat = d == 0
        let label = "\(isUp ? "+" : "")\(d) · 1h"
        let color: Color = isFlat ? ScoorPalette.inkTertiary
                                  : (isUp ? ScoorPalette.accent : ScoorPalette.night)
        return HStack(spacing: 4) {
            Image(systemName: isFlat ? "minus" : (isUp ? "arrow.up.right" : "arrow.down.right"))
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Country Section

    private var countrySection: some View {
        VStack(spacing: 14) {
            HStack {
                Text("국가별 감정 비교")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                Spacer()
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorldRegion.allCases) { region in
                        regionChip(region)
                    }
                }
                .padding(.horizontal, 18)
            }

            VStack(spacing: 10) {
                ForEach(detail.regional.sorted(by: { $0.score > $1.score })) { r in
                    regionRow(r)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
        }
        .padding(.top, 28)
    }

    private func regionChip(_ region: WorldRegion) -> some View {
        let isOn = selectedRegion == region
        let r = detail.regional.first(where: { $0.region == region })
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedRegion = region }
        } label: {
            HStack(spacing: 6) {
                Text(region.flag).font(.system(size: 13))
                Text(region.label).font(.system(size: 12, weight: .semibold))
                if let r {
                    Text("\(r.score)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isOn ? ScoorPalette.bgBase : ScoreTone.from(score: r.score).primary)
                }
            }
            .foregroundStyle(isOn ? ScoorPalette.bgBase : ScoorPalette.inkSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(isOn ? ScoorPalette.inkPrimary : Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private func regionRow(_ r: RegionalReaction) -> some View {
        let isSelected = selectedRegion == r.region
        let tone = ScoreTone.from(score: r.score)
        let width = max(0.04, CGFloat(r.score) / 100.0)
        return HStack(spacing: 12) {
            Text(r.region.flag).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(r.region.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Spacer()
                    Text("\(r.score)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tone.primary)
                    Text("· \(CompactCount.format(r.participants))명")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkTertiary)
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 4)
                        Capsule()
                            .fill(LinearGradient(
                                colors: [tone.primary.opacity(0.85), tone.primary],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * width, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.04) : Color.clear)
        )
    }

    // MARK: - Sports panel

    private func sportsPanel(_ s: SportsMetadata) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ScoorPalette.accent)
                Text("MATCH SCOOR")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(ScoorPalette.inkSecondary)
                Spacer()
                Text(s.status)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ScoorPalette.accent.opacity(0.16)))
                    .overlay(Capsule().stroke(ScoorPalette.accent.opacity(0.4), lineWidth: 0.5))
            }

            // 매치 스코어 헤더
            HStack(alignment: .center, spacing: 0) {
                teamBlock(s.home, alignment: .leading)
                Text("\(s.home.matchScore) : \(s.away.matchScore)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                teamBlock(s.away, alignment: .trailing)
            }

            // 팀 Scoor 게이지
            HStack(spacing: 10) {
                teamScoorCell(s.home)
                teamScoorCell(s.away)
            }

            // MVP
            if let mvp = s.mvp {
                mvpCell(mvp)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(ScoorPalette.bgRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(ScoorPalette.hairline, lineWidth: 0.6)
        )
        .padding(.horizontal, 18)
        .padding(.top, 28)
    }

    private func teamBlock(_ team: SportsTeam,
                           alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(team.crest).font(.system(size: 28))
            Text(team.abbr)
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(ScoorPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private func teamScoorCell(_ team: SportsTeam) -> some View {
        let tone = ScoreTone.from(score: team.fanScoor)
        return Button {
            scoreTarget = .team(team.abbr)
            showScoreSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(team.crest).font(.system(size: 14))
                    Text(team.abbr)
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(ScoorPalette.inkSecondary)
                    Spacer()
                    if let mine = mySubmissions[.team(team.abbr)] {
                        Text("나 \(mine)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ScoorPalette.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(ScoorPalette.accent.opacity(0.16)))
                    }
                }
                Text("\(team.fanScoor)")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(tone.primary)
                    .monospacedDigit()
                Text("팬 평균")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ScoorPalette.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableScale())
    }

    private func mvpCell(_ mvp: SportsMVP) -> some View {
        let tone = ScoreTone.from(score: mvp.fanScoor)
        return Button {
            scoreTarget = .mvp
            showScoreSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [ScoorPalette.accent.opacity(0.8), ScoorPalette.accent.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 40, height: 40)
                    Image(systemName: "star.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("MVP")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(ScoorPalette.accent)
                        Text(mvp.team)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(ScoorPalette.inkTertiary)
                    }
                    Text(mvp.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Text(mvp.line)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(mvp.fanScoor)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(tone.primary)
                        .monospacedDigit()
                    if let mine = mySubmissions[.mvp] {
                        Text("나 \(mine)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ScoorPalette.accent)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(ScoorPalette.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(PressableScale())
    }

    // MARK: - Recent reactions

    private var recentSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("최근 반응")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ScoorPalette.inkPrimary)
                Spacer()
                Text("\(detail.recent.count)+")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScoorPalette.inkTertiary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 28)
            .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(detail.recent) { r in
                    reactionRow(r)
                    Divider().background(ScoorPalette.hairline)
                }
                if detail.recent.isEmpty {
                    Text("아직 반응이 없어요. 첫 Scoor를 남겨주세요.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ScoorPalette.inkSecondary)
                        .padding(.vertical, 28)
                }
            }
        }
    }

    private func reactionRow(_ r: TopicReaction) -> some View {
        HStack(alignment: .top, spacing: 12) {
            avatarCircle(seed: r.identity.avatarSeed,
                         initial: r.identity.isAnonymous ? "?" :
                            String(r.identity.name.prefix(1)).uppercased())
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(r.identity.isAnonymous ? "익명" : r.identity.name)
                        .font(ScoorType.name)
                        .foregroundStyle(ScoorPalette.inkPrimary)
                    Text("·").font(ScoorType.meta).foregroundStyle(ScoorPalette.inkTertiary)
                    Text(r.region.flag).font(.system(size: 11))
                    Text("·").font(ScoorType.meta).foregroundStyle(ScoorPalette.inkTertiary)
                    Text(RelativeTime.short(from: r.postedAt))
                        .font(ScoorType.meta)
                        .foregroundStyle(ScoorPalette.inkTertiary)
                    Spacer()
                    FeedScoreDisplay(score: r.score, size: 17)
                }
                if let comment = r.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(ScoorPalette.inkPrimary.opacity(0.94))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func avatarCircle(seed: Int, initial: String) -> some View {
        let palette: [Color] = [
            Color(red: 0.43, green: 0.49, blue: 0.66),
            Color(red: 0.66, green: 0.45, blue: 0.51),
            Color(red: 0.51, green: 0.57, blue: 0.50),
            Color(red: 0.71, green: 0.55, blue: 0.39),
            Color(red: 0.50, green: 0.47, blue: 0.63),
            Color(red: 0.42, green: 0.55, blue: 0.55),
            Color(red: 0.62, green: 0.58, blue: 0.42),
            Color(red: 0.58, green: 0.49, blue: 0.55),
            Color(red: 0.45, green: 0.52, blue: 0.59)
        ]
        let idx = max(0, min(palette.count - 1, seed - 1))
        return ZStack {
            Circle().fill(palette[idx]).frame(width: 34, height: 34)
            Text(initial)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
        }
    }

    // MARK: - Bottom CTA

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [ScoorPalette.bgBase.opacity(0), ScoorPalette.bgBase],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)

            HStack(spacing: 10) {
                if let mine = mySubmissions[.match] ?? mySubmissions[scoreTarget] {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("내 Scoor \(mine)")
                            .font(.system(size: 13, weight: .bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(ScoorPalette.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(ScoorPalette.accent.opacity(0.14))
                    )
                    .overlay(
                        Capsule().stroke(ScoorPalette.accent.opacity(0.4), lineWidth: 0.6)
                    )
                }

                Button {
                    scoreTarget = .match
                    showScoreSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Text(mySubmissions[.match] == nil
                             ? "What's your Scoor?"
                             : "다시 매기기")
                            .font(.system(size: 15, weight: .bold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(LinearGradient(
                            colors: [ScoorPalette.accent, ScoorPalette.accent.opacity(0.92)],
                            startPoint: .top, endPoint: .bottom
                        ))
                    )
                    .shadow(color: ScoorPalette.accent.opacity(0.45), radius: 16, y: 6)
                }
                .buttonStyle(PressableScale())
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
            .background(ScoorPalette.bgBase)
        }
    }

    // MARK: - Submit feedback overlay

    private func feedbackOverlay(score: Int) -> some View {
        let tone = ScoreTone.from(score: score)
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 8)
                        .frame(width: 168, height: 168)
                    Circle()
                        .trim(from: 0, to: max(0.02, CGFloat(score) / 100.0))
                        .stroke(tone.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 168, height: 168)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(tone.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Text(feedbackMessage(for: score))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                Text("세계는 지금 이 토픽을 \(topic.globalScore)점으로 느끼고 있어요.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 36)
        }
        .onTapGesture { dismissFeedback() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                dismissFeedback()
            }
        }
    }

    private func dismissFeedback() {
        withAnimation(.easeOut(duration: 0.25)) { feedbackScore = nil }
    }

    private func feedbackMessage(for score: Int) -> String {
        switch score {
        case 90...100: return "당신의 Scoor가 세계에 더해졌어요."
        case 70...89:  return "당신은 \(score)점으로 반응했어요."
        case 40...69:  return "기록되었습니다. 세계가 같이 느낍니다."
        case 10...39:  return "당신의 감정도 세계의 일부에요."
        default:       return "Scoor 기록 완료."
        }
    }

    // MARK: - Submission handling

    private func handleSubmission(score: Int) {
        let target = scoreTarget
        mySubmissions[target] = score

        if target == .match {
            // Rough blend: globalScore = (오래된 평균 * 99 + 내 점수 * 1) / 100
            let blended = Double(topic.globalScore) * 0.985 + Double(score) * 0.015
            topic = WorldTopic(
                id: topic.id,
                category: topic.category,
                title: topic.title,
                emoji: topic.emoji,
                globalScore: Int(blended.rounded()),
                scoreDelta: topic.scoreDelta + (score > topic.globalScore ? 1 : -1),
                postsCount: topic.postsCount + 1,
                lastActivityAt: Date(),
                heat: topic.heat
            )
        }

        showScoreSheet = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            feedbackScore = score
        }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

// MARK: - ScoorGauge

/// 글로벌 점수 표시용 게이지 — 큰 숫자 + 호 + 그라데이션 띠.
struct ScoorGauge: View {
    let score: Int
    let tone: ScoreTone

    @State private var anim: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) * 0.95
            ZStack {
                // 후광
                Circle()
                    .fill(RadialGradient(
                        colors: [tone.primary.opacity(0.22), .clear],
                        center: .center, startRadius: 4, endRadius: size * 0.55
                    ))
                    .blur(radius: 18)

                // 배경 호
                Circle()
                    .trim(from: 0.08, to: 0.92)
                    .stroke(Color.white.opacity(0.06),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(126))

                // 점수 호
                Circle()
                    .trim(from: 0.08,
                          to: 0.08 + 0.84 * CGFloat(min(1, max(0, anim / 100.0))))
                    .stroke(
                        AngularGradient(
                            colors: [
                                tone.primary.opacity(0.55),
                                tone.primary,
                                tone.primary.opacity(0.85)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(126))

                // 숫자
                VStack(spacing: 4) {
                    Text("\(Int(anim.rounded()))")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(tone.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ 100")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(ScoorPalette.inkTertiary)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) {
                anim = Double(score)
            }
        }
        .onChange(of: score) { _, new in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
                anim = Double(new)
            }
        }
    }
}

// MARK: - Press style

private struct PressableScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    TopicDetailView(topic: MockWorld.topics[0])
}
