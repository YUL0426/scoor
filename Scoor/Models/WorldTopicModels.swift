//
//  WorldTopicModels.swift
//  Scoor
//
//  새 World 탭의 도메인 — “세계가 실시간으로 감정 점수를 매기는 토픽 피드”.
//  - WorldCategory: 카테고리 채널 (스포츠/정치/주식/크립토 …)
//  - WorldTopic: 한 주제(토트넘 vs 아스널, 비트코인 …) — 글로벌 평균 점수와 추세
//  - WorldPost: 그 주제에 대한 개별 유저의 한 줄 반응 (개인 점수 + 한 줄)
//  - WorldPulse: 상단 티커용 토픽 레벨 통계
//

import Foundation

// MARK: - Category

enum WorldCategory: String, CaseIterable, Identifiable, Hashable {
    case sports, politics, society, entertainment
    case stocks, crypto, tech
    case love, work, students, night

    var id: String { rawValue }

    /// 한국어 라벨.
    var label: String {
        switch self {
        case .sports:        return "스포츠"
        case .politics:      return "정치"
        case .society:       return "사회"
        case .entertainment: return "연예"
        case .stocks:        return "주식"
        case .crypto:        return "코인"
        case .tech:          return "테크"
        case .love:          return "연애"
        case .work:          return "직장"
        case .students:      return "학생"
        case .night:         return "새벽"
        }
    }

    /// 칩 좌측에 붙는 이모지 — “라이브 감정 채널” 느낌.
    var emoji: String {
        switch self {
        case .sports:        return "🏀"
        case .politics:      return "🗳"
        case .society:       return "🌧"
        case .entertainment: return "🎬"
        case .stocks:        return "📉"
        case .crypto:        return "🪙"
        case .tech:          return "🤖"
        case .love:          return "❤️"
        case .work:          return "💼"
        case .students:      return "📚"
        case .night:         return "🌙"
        }
    }
}

// MARK: - Heat

enum TopicHeat: String, Hashable {
    case hot       // 매우 활발
    case rising    // 점수 상승 추세
    case falling   // 점수 하락 추세
    case fresh     // 새로 올라온 토픽
    case calm      // 잔잔

    var label: String {
        switch self {
        case .hot:     return "🔥 활발히 토론 중"
        case .rising:  return "↑ 감정 상승"
        case .falling: return "↓ 감정 하락"
        case .fresh:   return "✨ 새 토픽"
        case .calm:    return "잔잔"
        }
    }
}

// MARK: - WorldTopic (집계 단위)

struct WorldTopic: Identifiable, Hashable {
    let id: UUID
    let category: WorldCategory
    let title: String          // "토트넘 vs 아스널"
    let emoji: String          // 토픽 자체 이모지 — 카테고리 이모지와 다를 수 있음
    let globalScore: Int       // 0~100, 글로벌 평균
    let scoreDelta: Int        // 최근 1시간 등락 (-100~+100)
    let postsCount: Int        // 누적 글 수
    let lastActivityAt: Date
    let heat: TopicHeat
}

// MARK: - WorldPost (개인 반응)

struct WorldPost: Identifiable, Hashable {
    let id: UUID
    let identity: LightIdentity
    let topic: WorldTopic
    let postedAt: Date
    let myScore: Int          // 이 유저가 매긴 점수
    let message: String       // 한 줄 감정 반응
    var reactions: PostReactions
}

// MARK: - WorldPulse (티커용)

struct WorldPulse: Identifiable, Hashable {
    enum Kind { case rising, falling, hottest, mostEmotional, mostPosts, fresh }
    let id = UUID()
    let kind: Kind
    let label: String
    let glyph: String
}

// MARK: - Region (글로벌 vs 국가별 반응 비교)

enum WorldRegion: String, CaseIterable, Identifiable, Hashable {
    case global, korea, japan, usa, europe, sea

    var id: String { rawValue }

    var label: String {
        switch self {
        case .global: return "Global"
        case .korea:  return "Korea"
        case .japan:  return "Japan"
        case .usa:    return "USA"
        case .europe: return "Europe"
        case .sea:    return "SEA"
        }
    }

    var flag: String {
        switch self {
        case .global: return "🌐"
        case .korea:  return "🇰🇷"
        case .japan:  return "🇯🇵"
        case .usa:    return "🇺🇸"
        case .europe: return "🇪🇺"
        case .sea:    return "🌏"
        }
    }
}

struct RegionalReaction: Hashable, Identifiable {
    var id: WorldRegion { region }
    let region: WorldRegion
    let score: Int           // 0~100
    let participants: Int    // 이 지역에서 점수 매긴 사람 수
}

// MARK: - Sports

struct SportsTeam: Hashable {
    let abbr: String       // "MUN"
    let name: String       // "Manchester United"
    let crest: String      // emoji (실제 앱에선 로고 이미지)
    let matchScore: Int    // 경기 득점
    let fanScoor: Int      // 0~100 팬 감정 점수
}

struct SportsMVP: Hashable {
    let name: String           // "Bruno Fernandes"
    let team: String           // "MUN"
    let line: String           // "2 goals · 1 assist"
    let fanScoor: Int          // 0~100
}

struct SportsMetadata: Hashable {
    let status: String         // "FT", "LIVE 73'", "Half-time"
    let home: SportsTeam
    let away: SportsTeam
    let mvp: SportsMVP?
}

/// 점수 입력 시 무엇을 점수 매길지 (스포츠 전용 분기).
enum ScoorTarget: Hashable, Identifiable {
    case match
    case team(String)        // team.abbr
    case mvp

    var id: String {
        switch self {
        case .match:        return "match"
        case .team(let a):  return "team-\(a)"
        case .mvp:          return "mvp"
        }
    }

    func label(detail: TopicDetail?) -> String {
        switch self {
        case .match: return "Match"
        case .team(let abbr):
            return detail?.sports?.home.abbr == abbr ? (detail?.sports?.home.abbr ?? abbr)
                 : (detail?.sports?.away.abbr ?? abbr)
        case .mvp:   return "MVP"
        }
    }
}

// MARK: - TopicReaction (한 토픽에 매겨진 다른 유저들의 반응)

struct TopicReaction: Identifiable, Hashable {
    let id: UUID
    let identity: LightIdentity
    let region: WorldRegion
    let score: Int
    let comment: String?
    let postedAt: Date
}

// MARK: - TopicDetail (디테일 화면 전용 메타데이터)

struct TopicDetail: Hashable {
    let source: String                 // "Sky Sports", "Bloomberg" …
    let summary: String                // 1~2줄 요약
    let coverHue: Double               // 0.0~1.0 — 그라데이션 색 시드
    let globalParticipants: Int        // 전세계 점수 매긴 인원
    let regional: [RegionalReaction]   // Region별 점수
    let sports: SportsMetadata?        // sports 토픽일 때만
    let recent: [TopicReaction]        // 최근 반응 6~10개
}

// MARK: - Sort

enum WorldSort: String, CaseIterable, Identifiable, Hashable {
    case live    = "실시간"
    case hot     = "지금 뜨거움"
    case trending = "급상승"

    var id: String { rawValue }
}

// MARK: - Mock

enum MockWorld {

    // 동일 identity 풀을 Feed와 공유 — 같은 LightIdentity 타입.
    private static let identities: [LightIdentity] = MockFeed.identities

    private static let now = Date()
    private static func ago(_ minutes: Int) -> Date {
        now.addingTimeInterval(-Double(minutes) * 60)
    }

    // MARK: Topics

    static let topics: [WorldTopic] = [
        .init(id: UUID(), category: .sports,
              title: "토트넘 vs 아스널", emoji: "⚽️",
              globalScore: 78, scoreDelta: +12, postsCount: 4_812,
              lastActivityAt: ago(1), heat: .hot),

        .init(id: UUID(), category: .stocks,
              title: "코스피 -3.2%", emoji: "📉",
              globalScore: 28, scoreDelta: -18, postsCount: 9_241,
              lastActivityAt: ago(3), heat: .falling),

        .init(id: UUID(), category: .crypto,
              title: "비트코인 $68k 돌파", emoji: "🪙",
              globalScore: 82, scoreDelta: +24, postsCount: 7_113,
              lastActivityAt: ago(2), heat: .rising),

        .init(id: UUID(), category: .politics,
              title: "대선 토론회", emoji: "🗳",
              globalScore: 41, scoreDelta: -6, postsCount: 12_408,
              lastActivityAt: ago(6), heat: .hot),

        .init(id: UUID(), category: .society,
              title: "서울 새벽 폭우", emoji: "🌧",
              globalScore: 35, scoreDelta: -9, postsCount: 1_882,
              lastActivityAt: ago(11), heat: .falling),

        .init(id: UUID(), category: .entertainment,
              title: "넷플릭스 ‘선의’ 시즌3", emoji: "🎬",
              globalScore: 88, scoreDelta: +5, postsCount: 3_204,
              lastActivityAt: ago(8), heat: .rising),

        .init(id: UUID(), category: .tech,
              title: "GPT-5 발표", emoji: "🤖",
              globalScore: 71, scoreDelta: +3, postsCount: 5_602,
              lastActivityAt: ago(14), heat: .hot),

        .init(id: UUID(), category: .love,
              title: "솔로 탈출 시즌", emoji: "❤️",
              globalScore: 62, scoreDelta: 0, postsCount: 2_341,
              lastActivityAt: ago(22), heat: .calm),

        .init(id: UUID(), category: .work,
              title: "주 4일제 논쟁", emoji: "💼",
              globalScore: 47, scoreDelta: -4, postsCount: 6_512,
              lastActivityAt: ago(30), heat: .hot),

        .init(id: UUID(), category: .students,
              title: "수능 D-30", emoji: "📚",
              globalScore: 33, scoreDelta: -2, postsCount: 4_088,
              lastActivityAt: ago(45), heat: .calm),

        .init(id: UUID(), category: .night,
              title: "새벽 감성", emoji: "🌙",
              globalScore: 38, scoreDelta: -1, postsCount: 1_244,
              lastActivityAt: ago(62), heat: .fresh),

        .init(id: UUID(), category: .sports,
              title: "KBO 한국시리즈", emoji: "⚾️",
              globalScore: 74, scoreDelta: +8, postsCount: 2_188,
              lastActivityAt: ago(85), heat: .rising)
    ]

    /// 카테고리별 인덱스를 미리 만들어 둠.
    static func topicsIn(_ category: WorldCategory) -> [WorldTopic] {
        topics.filter { $0.category == category }
    }

    // MARK: Posts

    static let posts: [WorldPost] = {
        func r(_ likes: Int, _ comments: Int, _ reposts: Int = 0,
               _ empathy: Int = 0, liked: Bool = false,
               mine: EmpathyReaction? = nil) -> PostReactions {
            PostReactions(likes: likes, comments: comments, reposts: reposts,
                          empathyTotal: empathy, likedByMe: liked, empathyByMe: mine)
        }

        // 토픽 id가 안정적이지 않으므로 index 매핑 헬퍼.
        func topic(_ i: Int) -> WorldTopic { topics[i] }

        return [
            .init(id: UUID(), identity: identities[2], topic: topic(0),
                  postedAt: ago(1), myScore: 92,
                  message: "오늘 경기 진짜 미쳤다.",
                  reactions: r(821, 142, 24, 88, liked: true)),

            .init(id: UUID(), identity: identities[1], topic: topic(1),
                  postedAt: ago(2), myScore: 18,
                  message: "내 ETF 또 박살. 그냥 보지 말걸.",
                  reactions: r(1_842, 421, 38, 612, mine: .hug)),

            .init(id: UUID(), identity: identities[0], topic: topic(2),
                  postedAt: ago(3), myScore: 89,
                  message: "비트 들고 있는 사람들 다 행복 회로 돌리는 중.",
                  reactions: r(421, 88, 12, 41)),

            .init(id: UUID(), identity: identities[6], topic: topic(3),
                  postedAt: ago(4), myScore: 22,
                  message: "토론회 보다가 한숨만 50번 쉼.",
                  reactions: r(2_140, 612, 88, 944, mine: .thought)),

            .init(id: UUID(), identity: identities[10], topic: topic(1),
                  postedAt: ago(5), myScore: 41,
                  message: "물타기는 도박이 아니라 신앙이다.",
                  reactions: r(612, 142, 24, 88)),

            .init(id: UUID(), identity: identities[12], topic: topic(4),
                  postedAt: ago(7), myScore: 28,
                  message: "출근길 신발 다 젖음. 오늘 망함.",
                  reactions: r(284, 38, 4, 91)),

            .init(id: UUID(), identity: identities[3], topic: topic(5),
                  postedAt: ago(8), myScore: 96,
                  message: "마지막 화 보고 2시간 멍 때림. 미친 작품.",
                  reactions: r(1_204, 218, 41, 188, liked: true)),

            .init(id: UUID(), identity: identities[8], topic: topic(2),
                  postedAt: ago(9), myScore: 28,
                  message: "코인 올라도 내 지갑은 안 오른다…",
                  reactions: r(891, 142, 12, 412, mine: .hug)),

            .init(id: UUID(), identity: identities[14], topic: topic(6),
                  postedAt: ago(10), myScore: 84,
                  message: "GPT-5 시연 영상 본 뒤로 일이 손에 안 잡힘.",
                  reactions: r(602, 124, 21, 88)),

            .init(id: UUID(), identity: identities[11], topic: topic(8),
                  postedAt: ago(13), myScore: 38,
                  message: "주 4일제는 좋은데 임금 깎이면 안 함…",
                  reactions: r(891, 412, 24, 188)),

            .init(id: UUID(), identity: identities[15], topic: topic(7),
                  postedAt: ago(18), myScore: 71,
                  message: "오랜만에 설렘이라는 단어 떠올림.",
                  reactions: r(312, 41, 6, 88)),

            .init(id: UUID(), identity: identities[16], topic: topic(9),
                  postedAt: ago(24), myScore: 22,
                  message: "수능 D-30. 머리 좀 멈췄으면.",
                  reactions: r(1_402, 312, 18, 612, mine: .hug)),

            .init(id: UUID(), identity: identities[5], topic: topic(0),
                  postedAt: ago(28), myScore: 84,
                  message: "Son 진짜 클러치. 오늘은 토트넘 응원하길 잘함.",
                  reactions: r(412, 88, 12, 41)),

            .init(id: UUID(), identity: identities[13], topic: topic(10),
                  postedAt: ago(32), myScore: 28,
                  message: "새벽 3시 28분. 잠 안 옴. 머리만 시끄러움.",
                  reactions: r(2_104, 412, 88, 1_102, mine: .moon)),

            .init(id: UUID(), identity: identities[7], topic: topic(5),
                  postedAt: ago(38), myScore: 82,
                  message: "OST 너무 좋아서 어제부터 무한 반복.",
                  reactions: r(178, 22, 4, 18)),

            .init(id: UUID(), identity: identities[17], topic: topic(11),
                  postedAt: ago(48), myScore: 91,
                  message: "한국시리즈 7차전 가즈아.",
                  reactions: r(412, 88, 18, 41, liked: true)),

            .init(id: UUID(), identity: identities[9], topic: topic(8),
                  postedAt: ago(55), myScore: 24,
                  message: "야근 끝나고 보니 또 12시. 인생 어디 갔지.",
                  reactions: r(1_201, 312, 24, 612, mine: .thought)),

            .init(id: UUID(), identity: identities[4], topic: topic(6),
                  postedAt: ago(72), myScore: 64,
                  message: "AI가 빨라질수록 내가 느려지는 기분.",
                  reactions: r(682, 142, 28, 188)),

            .init(id: UUID(), identity: identities[2], topic: topic(3),
                  postedAt: ago(95), myScore: 38,
                  message: "공약은 다 잊혔고 표정 싸움만 남았다.",
                  reactions: r(1_842, 412, 88, 612, mine: .thought)),

            .init(id: UUID(), identity: identities[0], topic: topic(7),
                  postedAt: ago(130), myScore: 78,
                  message: "친구가 ‘너 좀 변했다’ 했다. 좋은 의미라 믿는 중.",
                  reactions: r(412, 88, 12, 88))
        ]
    }()

    static func postsIn(_ category: WorldCategory?) -> [WorldPost] {
        guard let c = category else { return posts }
        return posts.filter { $0.topic.category == c }
    }

    // MARK: Pulses

    static let pulses: [WorldPulse] = [
        .init(kind: .rising,        label: "비트코인 감정 ↑ +24",       glyph: "arrow.up.right"),
        .init(kind: .falling,       label: "코스피 감정 ↓ -18",         glyph: "arrow.down.right"),
        .init(kind: .hottest,       label: "가장 뜨거움 · 대선 토론회",  glyph: "flame.fill"),
        .init(kind: .mostEmotional, label: "오늘 가장 감정적 · 직장",   glyph: "heart.text.square"),
        .init(kind: .mostPosts,     label: "오늘 글 71,482",            glyph: "text.bubble.fill"),
        .init(kind: .fresh,         label: "새 토픽 · GPT-5 발표",      glyph: "sparkles")
    ]

    /// 헤더 우상단 표시용.
    static let liveActiveCount: Int = 84_119
    static let liveAverage: Int = 58

    // MARK: Details (per topic title)

    /// 토픽 타이틀 → TopicDetail 매핑. UUID는 토픽 생성 시 동적으로 바뀌므로
    /// 타이틀을 키로 사용한다.
    static let details: [String: TopicDetail] = {

        func reactions(_ tuples: [(name: String, anon: Bool, seed: Int,
                                    region: WorldRegion, score: Int,
                                    comment: String?, minutesAgo: Int)])
        -> [TopicReaction] {
            tuples.map { t in
                TopicReaction(
                    id: UUID(),
                    identity: LightIdentity(name: t.name, isAnonymous: t.anon, avatarSeed: t.seed),
                    region: t.region,
                    score: t.score,
                    comment: t.comment,
                    postedAt: ago(t.minutesAgo)
                )
            }
        }

        var d: [String: TopicDetail] = [:]

        // 1) 스포츠 — 토트넘 vs 아스널
        d["토트넘 vs 아스널"] = TopicDetail(
            source: "Sky Sports",
            summary: "북런던 더비 — 후반 추가시간 결승골로 토트넘이 3:2 승리.",
            coverHue: 0.06,
            globalParticipants: 184_220,
            regional: [
                .init(region: .global, score: 78, participants: 184_220),
                .init(region: .korea,  score: 91, participants: 38_412),
                .init(region: .japan,  score: 73, participants: 14_318),
                .init(region: .usa,    score: 65, participants: 22_104),
                .init(region: .europe, score: 84, participants: 71_233),
                .init(region: .sea,    score: 69, participants: 12_882)
            ],
            sports: SportsMetadata(
                status: "FT",
                home: .init(abbr: "TOT", name: "Tottenham", crest: "⚪️",
                            matchScore: 3, fanScoor: 89),
                away: .init(abbr: "ARS", name: "Arsenal", crest: "🔴",
                            matchScore: 2, fanScoor: 41),
                mvp: .init(name: "Son Heung-min", team: "TOT",
                           line: "2 goals · 1 assist", fanScoor: 97)
            ),
            recent: reactions([
                ("Yul", false, 1, .korea, 96, "손흥민 진짜 미쳤다. 인생 경기.", 1),
                ("Lea", false, 6, .europe, 84, "Arsenal collapsed in the last 10 mins.", 2),
                ("익명", true, 7, .usa, 62, "Refs were terrible tbh.", 3),
                ("Mika", false, 6, .japan, 75, "ソンの2点目、神。", 5),
                ("Jin", false, 1, .korea, 92, "토트넘 팬으로 10년째인데 오늘이 최고.", 7),
                ("Ren", false, 5, .europe, 38, "as an Arsenal fan im not okay", 12)
            ])
        )

        // 2) 스포츠 — KBO 한국시리즈
        d["KBO 한국시리즈"] = TopicDetail(
            source: "Sports Korea",
            summary: "KIA vs 두산, 시리즈 3:3 — 오늘 밤 7차전.",
            coverHue: 0.97,
            globalParticipants: 42_318,
            regional: [
                .init(region: .global, score: 74, participants: 42_318),
                .init(region: .korea,  score: 88, participants: 38_112),
                .init(region: .japan,  score: 51, participants: 2_140),
                .init(region: .usa,    score: 42, participants: 1_320),
                .init(region: .europe, score: 38, participants: 412),
                .init(region: .sea,    score: 47, participants: 334)
            ],
            sports: SportsMetadata(
                status: "Game 7 · 19:00 KST",
                home: .init(abbr: "KIA", name: "KIA Tigers", crest: "🐯",
                            matchScore: 3, fanScoor: 86),
                away: .init(abbr: "DSN", name: "Doosan Bears", crest: "🐻",
                            matchScore: 3, fanScoor: 79),
                mvp: nil
            ),
            recent: reactions([
                ("도연", false, 2, .korea, 91, "7차전 한국시리즈 가즈아!!", 4),
                ("Jin", false, 1, .korea, 84, "심장 떨려서 못 보겠음.", 9),
                ("Sora", false, 5, .japan, 52, "日本シリーズより面白い説。", 18)
            ])
        )

        // 3) 크립토 — 비트코인 $68k 돌파
        d["비트코인 $68k 돌파"] = TopicDetail(
            source: "Bloomberg",
            summary: "BTC 24시간 +6.4%, 사상 두 번째 고점 갱신 직전.",
            coverHue: 0.11,
            globalParticipants: 96_402,
            regional: [
                .init(region: .global, score: 82, participants: 96_402),
                .init(region: .korea,  score: 78, participants: 21_801),
                .init(region: .japan,  score: 71, participants: 14_280),
                .init(region: .usa,    score: 89, participants: 38_120),
                .init(region: .europe, score: 76, participants: 18_440),
                .init(region: .sea,    score: 84, participants: 3_761)
            ],
            sports: nil,
            recent: reactions([
                ("Nico", false, 8, .usa, 95, "FINALLY. We are so back.", 1),
                ("준", false, 3, .korea, 78, "물려있던 거 드디어 본전.", 4),
                ("익명", true, 9, .europe, 41, "Boring rally, no real volume.", 8),
                ("Mika", false, 6, .japan, 84, "$100k 行ける?", 16)
            ])
        )

        // 4) 정치 — 대선 토론회
        d["대선 토론회"] = TopicDetail(
            source: "JTBC",
            summary: "1차 TV 토론. 후보 4인, 90분 진행 — 표정 싸움이 절반.",
            coverHue: 0.55,
            globalParticipants: 412_882,
            regional: [
                .init(region: .global, score: 41, participants: 412_882),
                .init(region: .korea,  score: 38, participants: 386_120),
                .init(region: .japan,  score: 58, participants: 8_220),
                .init(region: .usa,    score: 52, participants: 12_400),
                .init(region: .europe, score: 55, participants: 4_820),
                .init(region: .sea,    score: 49, participants: 1_322)
            ],
            sports: nil,
            recent: reactions([
                ("익명", true, 3, .korea, 22, "한숨만 50번 쉼.", 4),
                ("Hana", false, 4, .korea, 18, "공약은 다 잊혔고 표정 싸움만.", 9),
                ("Sol", false, 8, .usa, 55, "Looked tame compared to US debates.", 24)
            ])
        )

        // 5) 사회 — 서울 새벽 폭우
        d["서울 새벽 폭우"] = TopicDetail(
            source: "기상청",
            summary: "시간당 60mm 폭우. 출근길 침수 다발.",
            coverHue: 0.62,
            globalParticipants: 18_812,
            regional: [
                .init(region: .global, score: 35, participants: 18_812),
                .init(region: .korea,  score: 28, participants: 17_982),
                .init(region: .japan,  score: 64, participants: 412)
            ],
            sports: nil,
            recent: reactions([
                ("준", false, 3, .korea, 22, "신발 다 젖음. 오늘 망함.", 7),
                ("Hana", false, 4, .korea, 41, "비 소리는 좋다. 출근만 빼고.", 18)
            ])
        )

        // 6) 엔터 — 넷플릭스 ‘선의’ 시즌3
        d["넷플릭스 ‘선의’ 시즌3"] = TopicDetail(
            source: "Netflix",
            summary: "마지막 화 30분이 작품 전체를 뒤집음. 시즌3 공개.",
            coverHue: 0.85,
            globalParticipants: 51_882,
            regional: [
                .init(region: .global, score: 88, participants: 51_882),
                .init(region: .korea,  score: 92, participants: 28_410),
                .init(region: .japan,  score: 84, participants: 8_220),
                .init(region: .usa,    score: 78, participants: 7_412),
                .init(region: .europe, score: 81, participants: 5_120),
                .init(region: .sea,    score: 86, participants: 2_720)
            ],
            sports: nil,
            recent: reactions([
                ("Hana", false, 4, .korea, 96, "엔딩 보고 2시간 멍 때림.", 8),
                ("Nico", false, 8, .usa, 82, "Best season finale of the year, hands down.", 38),
                ("Mika", false, 6, .japan, 88, "OST 神。", 38)
            ])
        )

        // 7) 테크 — GPT-5 발표
        d["GPT-5 발표"] = TopicDetail(
            source: "OpenAI",
            summary: "추론·코딩·에이전트 데모. ‘진짜 비서’ 시연 영상이 화제.",
            coverHue: 0.30,
            globalParticipants: 124_410,
            regional: [
                .init(region: .global, score: 71, participants: 124_410),
                .init(region: .korea,  score: 74, participants: 18_220),
                .init(region: .japan,  score: 62, participants: 11_440),
                .init(region: .usa,    score: 84, participants: 48_120),
                .init(region: .europe, score: 58, participants: 24_220),
                .init(region: .sea,    score: 72, participants: 8_410)
            ],
            sports: nil,
            recent: reactions([
                ("Sol", false, 8, .usa, 91, "Coding demo was unreal.", 10),
                ("준", false, 3, .korea, 84, "일이 손에 안 잡힘.", 14),
                ("Sora", false, 5, .japan, 55, "怖い気もする。", 32)
            ])
        )

        // 8) 코스피
        d["코스피 -3.2%"] = TopicDetail(
            source: "한국경제",
            summary: "외국인 매도 폭주. 반도체 약세가 끌어내림.",
            coverHue: 0.0,
            globalParticipants: 78_220,
            regional: [
                .init(region: .global, score: 28, participants: 78_220),
                .init(region: .korea,  score: 22, participants: 71_220),
                .init(region: .japan,  score: 51, participants: 3_812),
                .init(region: .usa,    score: 48, participants: 2_120)
            ],
            sports: nil,
            recent: reactions([
                ("준", false, 3, .korea, 18, "내 ETF 또 박살.", 2),
                ("도연", false, 2, .korea, 41, "물타기는 도박이 아니라 신앙.", 5)
            ])
        )

        return d
    }()

    /// 토픽에 대한 디테일 — 매핑 없으면 placeholder.
    static func detail(for topic: WorldTopic) -> TopicDetail {
        if let d = details[topic.title] { return d }
        // Placeholder — 매핑이 없는 토픽도 디테일 화면이 비어 보이지 않게.
        return TopicDetail(
            source: topic.category.label,
            summary: "지금 막 올라온 토픽이에요. 첫 반응을 남겨주세요.",
            coverHue: 0.5,
            globalParticipants: max(topic.postsCount, 1),
            regional: [
                .init(region: .global, score: topic.globalScore, participants: topic.postsCount),
                .init(region: .korea,  score: min(100, topic.globalScore + 4),
                      participants: max(1, topic.postsCount / 3)),
                .init(region: .japan,  score: max(0, topic.globalScore - 5),
                      participants: max(1, topic.postsCount / 6)),
                .init(region: .usa,    score: max(0, topic.globalScore - 9),
                      participants: max(1, topic.postsCount / 5)),
                .init(region: .europe, score: topic.globalScore,
                      participants: max(1, topic.postsCount / 4))
            ],
            sports: nil,
            recent: []
        )
    }
}
