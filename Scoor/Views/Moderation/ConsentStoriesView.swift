import SwiftUI

/// Bundled examples introduce Scoor before consent, without fetching a public feed.
struct ConsentStoriesView: View {
    var isPaused = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var index = 0
    @State private var userPaused = false
    @State private var storyOpacity = 1.0
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize = 96

    private var shouldRotate: Bool {
        scenePhase == .active && !isPaused && !userPaused && automaticPlaybackAvailable
    }

    private var automaticPlaybackAvailable: Bool {
        // Long examples should stay still while readers scroll at large text sizes.
        !reduceMotion && !voiceOverEnabled && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LegalPolicy.text("오늘의 기록", "Today's entries"))
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 8)
                Button { userPaused.toggle() } label: {
                    Image(systemName: userPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(userPaused
                    ? LegalPolicy.text("예시 기록 자동 전환 재생", "Play example stories")
                    : LegalPolicy.text("예시 기록 자동 전환 일시 정지", "Pause example stories"))
                .accessibilityIdentifier("legal-story-pause")
                .opacity(automaticPlaybackAvailable ? 1 : 0)
                .disabled(!automaticPlaybackAvailable)
                .accessibilityHidden(!automaticPlaybackAvailable)
            }

            Spacer(minLength: 0)

            story(ConsentStory.examples[index])
            .opacity(storyOpacity)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    ForEach(ConsentStory.examples.indices, id: \.self) { position in
                        Capsule()
                            .fill(Color.white.opacity(position == index ? 0.85 : 0.22))
                            .frame(width: position == index ? 16 : 4, height: 4)
                    }
                }
                .accessibilityHidden(true)
                Text(LegalPolicy.text("기록 예시", "Example entries"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 4)
        .padding(.bottom, 24)
        .task(id: shouldRotate) {
            guard shouldRotate else { storyOpacity = 1; return }
            defer { storyOpacity = 1 }
            do {
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(4.2))
                    withAnimation(.easeOut(duration: 0.35)) { storyOpacity = 0 }
                    try await Task.sleep(for: .seconds(0.35))
                    try Task.checkCancellation()
                    index = (index + 1) % ConsentStory.examples.count
                    withAnimation(.easeIn(duration: 0.45)) { storyOpacity = 1 }
                    try await Task.sleep(for: .seconds(0.45))
                }
            } catch {
                // The view disappearing or pausing cancels its rotation.
            }
        }
    }

    private func story(_ example: ConsentStory) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(example.flag).font(.system(size: 19))
                Text(example.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text("·")
                Text(LegalPolicy.text(example.placeKO, example.placeEN))
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .foregroundStyle(.white)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(example.score)")
                    .font(.system(size: scoreSize, weight: .bold, design: .rounded))
                    .tracking(-5)
                    .foregroundStyle(example.color)
                    .monospacedDigit()
                Text("/ 100")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "오늘의 점수 \(example.score)점"))

            Text(LegalPolicy.text(example.reasonKO, example.reasonEN))
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .top)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("legal-story-\(example.id)")
    }
}

private struct ConsentStory {
    let id: String
    let flag: String
    let name: String
    let placeKO: String
    let placeEN: String
    let score: Int
    let reasonKO: String
    let reasonEN: String
    let color: Color

    static let examples: [Self] = [
        // Fictional individual entries, not statements about a country's culture.
        // Local-language source copy is kept alongside its KO/EN adaptations.
        .init(id: "seoul", flag: "🇰🇷", name: "min", placeKO: "대한민국, 서울", placeEN: "Seoul, South Korea", score: 86,
              reasonKO: "오늘 팀장님 휴가라\n간만에 여름방학 ㅋㅋ",
              reasonEN: "My boss is on vacation.\nFeels like summer break lol.",
              color: Color(red: 1, green: 0.57, blue: 0.47)),
        // ja-JP: 残業したけど、帰りに買ったコンビニのプリンが当たりだった。
        .init(id: "tokyo", flag: "🇯🇵", name: "sora", placeKO: "일본, 도쿄", placeEN: "Tokyo, Japan", score: 58,
              reasonKO: "야근했는데 집에 오는 길에 산\n편의점 푸딩이 의외로 맛있었음",
              reasonEN: "Worked late, but that convenience-store\npudding was actually really good.",
              color: Color(red: 0.86, green: 0.8, blue: 0.65)),
        // fr-FR: J’ai raté le métro et pris la pluie. J’aurais dû rester au lit.
        .init(id: "paris", flag: "🇫🇷", name: "leo", placeKO: "프랑스, 파리", placeEN: "Paris, France", score: 32,
              reasonKO: "지하철 놓치고 비까지 맞음.\n그냥 침대에 있을걸",
              reasonEN: "Missed the metro and got rained on.\nShould’ve stayed in bed.",
              color: Color(red: 0.59, green: 0.7, blue: 0.85)),
        // pt-BR: Salário na conta e amanhã é folga. Hoje tem pizza com a galera kkk
        .init(id: "saopaulo", flag: "🇧🇷", name: "lia", placeKO: "브라질, 상파울루", placeEN: "São Paulo, Brazil", score: 94,
              reasonKO: "월급 들어왔고 내일은 쉬는 날.\n오늘은 친구들이랑 피자 먹기로 ㅋㅋ",
              reasonEN: "Got paid and I’m off tomorrow.\nPizza with friends tonight haha.",
              color: Color(red: 0.7, green: 0.83, blue: 0.65))
    ]
}
