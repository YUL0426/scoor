//
//  FeedModels.swift
//  Scoor
//
//  Toss Community / Threads 톤의 감정 커뮤니티 피드 도메인.
//  - 점수 + 한 줄이 본문, 좋아요·댓글·리포스트·공감이 인터랙션
//  - 익명·라이트 정체성, 짧은 메타데이터
//

import Foundation

// MARK: - Mood (Filter + Post Tag 겸용)

enum Mood: String, CaseIterable, Identifiable, Hashable {
    case happy
    case burnout
    case lonely
    case calm
    case healing
    case work
    case love
    case night
    case students

    var id: String { rawValue }

    var label: String {
        switch self {
        case .happy:    return "행복"
        case .burnout:  return "번아웃"
        case .lonely:   return "외로움"
        case .calm:     return "고요"
        case .healing:  return "회복"
        case .work:     return "일"
        case .love:     return "사랑"
        case .night:    return "새벽"
        case .students: return "학생"
        }
    }

    var hashtag: String { "#\(label)" }
}

// MARK: - Weather (옵션 메타)

enum Weather: String, Hashable {
    case sunny, cloudy, rainy, snowy, night
    var glyph: String {
        switch self {
        case .sunny:  return "☀️"
        case .cloudy: return "☁️"
        case .rainy:  return "🌧️"
        case .snowy:  return "❄️"
        case .night:  return "🌙"
        }
    }
}

// MARK: - Identity

struct LightIdentity: Hashable {
    let name: String
    let isAnonymous: Bool
    /// 1~9 사이의 작은 정수 — 아바타 색 시드.
    let avatarSeed: Int
}

// MARK: - Reactions

enum EmpathyReaction: String, CaseIterable, Identifiable, Hashable {
    case hug, moon, sun, thought

    var id: String { rawValue }
    var glyph: String {
        switch self {
        case .hug:     return "🫂"
        case .moon:    return "🌙"
        case .sun:     return "☀️"
        case .thought: return "💭"
        }
    }
}

struct PostReactions: Hashable {
    var likes: Int
    var comments: Int
    var reposts: Int
    var empathyTotal: Int
    var likedByMe: Bool
    var empathyByMe: EmpathyReaction?
}

// MARK: - Feed Entry

struct FeedEntry: Identifiable, Hashable {
    let id: UUID
    let identity: LightIdentity
    let countryFlag: String
    let city: String
    let postedAt: Date
    let score: Int
    let message: String
    let primaryMood: Mood
    let extraTags: [Mood]
    let weather: Weather?
    var reactions: PostReactions
    /// 어드민이 등록한 공식 글. 앱은 "Scoor" 이름 옆에 배지를 붙여, 운영자가 쓴
    /// 글이 일반 사용자 글로 읽히지 않게 한다 (0007_feed.sql 참조).
    var isOfficial: Bool = false
    /// 작성자 계정. 신고 시트가 "이 사람 차단"까지 제안하는 데 쓴다. 익명 글과
    /// 공식 글, 그리고 시드 경로에서는 nil이다.
    var authorId: UUID? = nil

    static func == (lhs: FeedEntry, rhs: FeedEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Live Pulse (compact ticker용)

struct LivePulse: Identifiable, Hashable {
    enum Kind { case rising, falling, common, topCity, count, mood }
    let id = UUID()
    let kind: Kind
    /// 한 줄 ticker 문자열 ("서울 평균 ↑ 71")
    let label: String
    /// 좌측 글리프 (이모지 or SF Symbol 이름)
    let glyph: String
}

// MARK: - Sort mode (실시간 / 인기 / 비슷한 기분)

enum FeedSort: String, CaseIterable, Identifiable, Hashable {
    case live      = "실시간"
    case popular   = "인기"
    case similar   = "비슷한 기분"

    var id: String { rawValue }
}

// MARK: - Mock

enum MockFeed {

    static let identities: [LightIdentity] = [
        .init(name: "Yul",   isAnonymous: false, avatarSeed: 1),
        .init(name: "M",     isAnonymous: false, avatarSeed: 2),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 3),
        .init(name: "Hana",  isAnonymous: false, avatarSeed: 4),
        .init(name: "Sora",  isAnonymous: false, avatarSeed: 5),
        .init(name: "Lea",   isAnonymous: false, avatarSeed: 6),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 7),
        .init(name: "Nico",  isAnonymous: false, avatarSeed: 8),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 9),
        .init(name: "Jin",   isAnonymous: false, avatarSeed: 1),
        .init(name: "도연",   isAnonymous: false, avatarSeed: 2),
        .init(name: "준",     isAnonymous: false, avatarSeed: 3),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 4),
        .init(name: "Ren",   isAnonymous: false, avatarSeed: 5),
        .init(name: "Mika",  isAnonymous: false, avatarSeed: 6),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 7),
        .init(name: "Sol",   isAnonymous: false, avatarSeed: 8),
        .init(name: "익명",   isAnonymous: true,  avatarSeed: 9)
    ]

    static let entries: [FeedEntry] = {
        let now = Date()
        func ago(_ minutes: Int) -> Date { now.addingTimeInterval(-Double(minutes) * 60) }

        func r(_ likes: Int, _ comments: Int, _ reposts: Int = 0,
               _ empathy: Int = 0,
               liked: Bool = false,
               mine: EmpathyReaction? = nil) -> PostReactions {
            PostReactions(likes: likes, comments: comments, reposts: reposts,
                          empathyTotal: empathy, likedByMe: liked, empathyByMe: mine)
        }

        return [
            .init(id: UUID(), identity: identities[2],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(1), score: 24,
                  message: "퇴근길에 그냥 다 내려놓고 싶었어.",
                  primaryMood: .burnout, extraTags: [.lonely, .work],
                  weather: .rainy,
                  reactions: r(312, 41, 8, 188, mine: .hug)),

            .init(id: UUID(), identity: identities[0],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(2), score: 82,
                  message: "오늘은 조금 덜 외로웠다.",
                  primaryMood: .healing, extraTags: [.calm],
                  weather: .cloudy,
                  reactions: r(204, 23, 2, 71, liked: true)),

            .init(id: UUID(), identity: identities[1],
                  countryFlag: "🇯🇵", city: "Tokyo",
                  postedAt: ago(4), score: 38,
                  message: "야근 끝나고 전철 놓침. 그냥 웃겼다.",
                  primaryMood: .burnout, extraTags: [.work, .night],
                  weather: .night,
                  reactions: r(411, 67, 12, 154)),

            .init(id: UUID(), identity: identities[10],
                  countryFlag: "🇰🇷", city: "Busan",
                  postedAt: ago(6), score: 91,
                  message: "진짜 오랜만에 행복한 하루.",
                  primaryMood: .happy, extraTags: [.love],
                  weather: .sunny,
                  reactions: r(528, 88, 14, 220, liked: true)),

            .init(id: UUID(), identity: identities[6],
                  countryFlag: "🇺🇸", city: "New York",
                  postedAt: ago(8), score: 49,
                  message: "한 게 없는데 피곤해. 침대에서 못 나옴.",
                  primaryMood: .burnout, extraTags: [.lonely],
                  weather: nil,
                  reactions: r(842, 134, 21, 401, mine: .hug)),

            .init(id: UUID(), identity: identities[11],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(11), score: 67,
                  message: "발표 망한 줄 알았는데 칭찬받음. 어리둥절.",
                  primaryMood: .work, extraTags: [.students],
                  weather: nil,
                  reactions: r(231, 42, 3, 18)),

            .init(id: UUID(), identity: identities[3],
                  countryFlag: "🇰🇷", city: "Daegu",
                  postedAt: ago(14), score: 54,
                  message: "오늘은 그냥 평범한 하루. 그게 다행이지.",
                  primaryMood: .calm, extraTags: [.healing],
                  weather: .cloudy,
                  reactions: r(118, 14, 0, 22)),

            .init(id: UUID(), identity: identities[15],
                  countryFlag: "🇫🇷", city: "Paris",
                  postedAt: ago(18), score: 78,
                  message: "오늘 누군가의 농담에 진짜로 웃었다.",
                  primaryMood: .happy, extraTags: [.healing],
                  weather: .sunny,
                  reactions: r(167, 19, 2, 33)),

            .init(id: UUID(), identity: identities[12],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(22), score: 19,
                  message: "이별 통보 받음. 아직 실감 안 남.",
                  primaryMood: .lonely, extraTags: [.love, .night],
                  weather: .rainy,
                  reactions: r(1842, 287, 41, 924, mine: .thought)),

            .init(id: UUID(), identity: identities[4],
                  countryFlag: "🇯🇵", city: "Osaka",
                  postedAt: ago(28), score: 88,
                  message: "예상치 못한 보너스. 오늘은 다 사주고 싶다.",
                  primaryMood: .happy, extraTags: [.work],
                  weather: .sunny,
                  reactions: r(389, 51, 9, 92, liked: true)),

            .init(id: UUID(), identity: identities[16],
                  countryFlag: "🇰🇷", city: "Incheon",
                  postedAt: ago(33), score: 41,
                  message: "시험 망함. 근데 진짜 더는 못하겠음.",
                  primaryMood: .students, extraTags: [.burnout],
                  weather: nil,
                  reactions: r(672, 119, 8, 254, mine: .hug)),

            .init(id: UUID(), identity: identities[7],
                  countryFlag: "🇨🇦", city: "Toronto",
                  postedAt: ago(42), score: 71,
                  message: "비 오는 창밖 보면서 라떼. 충분.",
                  primaryMood: .calm, extraTags: [.healing],
                  weather: .rainy,
                  reactions: r(94, 8, 1, 12)),

            .init(id: UUID(), identity: identities[13],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(54), score: 33,
                  message: "새벽 3시. 잠도 안 오고 머릿속만 시끄러움.",
                  primaryMood: .night, extraTags: [.lonely, .burnout],
                  weather: .night,
                  reactions: r(2104, 312, 67, 1102, mine: .moon)),

            .init(id: UUID(), identity: identities[5],
                  countryFlag: "🇪🇸", city: "Barcelona",
                  postedAt: ago(68), score: 84,
                  message: "햇빛이 너무 좋아서 잠깐 멍 때렸음.",
                  primaryMood: .calm, extraTags: [.healing],
                  weather: .sunny,
                  reactions: r(212, 18, 4, 41)),

            .init(id: UUID(), identity: identities[14],
                  countryFlag: "🇯🇵", city: "Kyoto",
                  postedAt: ago(85), score: 62,
                  message: "혼밥인데 의외로 평화로움.",
                  primaryMood: .calm, extraTags: [.healing, .lonely],
                  weather: .cloudy,
                  reactions: r(143, 22, 1, 28)),

            .init(id: UUID(), identity: identities[17],
                  countryFlag: "🇰🇷", city: "Seoul",
                  postedAt: ago(108), score: 96,
                  message: "고백 성공함. 손이 아직도 떨림.",
                  primaryMood: .love, extraTags: [.happy],
                  weather: .sunny,
                  reactions: r(3211, 482, 121, 871, liked: true)),

            .init(id: UUID(), identity: identities[8],
                  countryFlag: "🇩🇪", city: "Berlin",
                  postedAt: ago(132), score: 47,
                  message: "괜찮은 척하는 게 더 힘들었던 하루.",
                  primaryMood: .lonely, extraTags: [.burnout],
                  weather: nil,
                  reactions: r(891, 142, 18, 312, mine: .thought)),

            .init(id: UUID(), identity: identities[9],
                  countryFlag: "🇦🇺", city: "Sydney",
                  postedAt: ago(165), score: 73,
                  message: "오랜만에 친구랑 통화. 별 거 없는데 좋다.",
                  primaryMood: .healing, extraTags: [.love],
                  weather: .sunny,
                  reactions: r(78, 6, 0, 11))
        ]
    }()

    /// LIVE PULSE 티커 — 짧고 빠르게 읽히는 문장들.
    static let pulses: [LivePulse] = [
        .init(kind: .count,    label: "오늘 12,482명이 기록 중",     glyph: "circle.fill"),
        .init(kind: .rising,   label: "서울 평균 ↑ 71",             glyph: "arrow.up.right"),
        .init(kind: .falling,  label: "도쿄 번아웃 늘어남",          glyph: "arrow.down.right"),
        .init(kind: .common,   label: "가장 많은 감정 · 외로움",      glyph: "person.2.fill"),
        .init(kind: .topCity,  label: "가장 환한 도시 · 오사카 84",   glyph: "sparkles"),
        .init(kind: .mood,     label: "새벽 피드 · 조용함",           glyph: "moon.fill")
    ]

    /// 헤더 우상단 통계 — "오늘 12,482명 · 평균 67".
    static let todayCount: Int = 12_482
    static let todayAverage: Int = 67
}
