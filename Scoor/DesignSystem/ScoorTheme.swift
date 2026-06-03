//
//  ScoorTheme.swift
//  Scoor
//
//  Feed 탭의 토큰 (Toss Community 톤).
//  - 검정 베이스 + Scoor 레드 액센트
//  - 시네마틱 그라데이션·후광 제거 → 가독성·밀도·속도 우선
//  - 카드 박스 대신 hairline divider 위주
//

import SwiftUI

// MARK: - Palette

enum ScoorPalette {
    /// 거의 순흑에 가까운 베이스 — Toss·X 다크 스타일.
    static let bgBase    = Color(red: 0.039, green: 0.039, blue: 0.043)
    /// surface — 카드는 박스를 쓰지 않지만, 필요한 곳(필터 칩 활성 등)에 사용.
    static let bgRaised  = Color(red: 0.090, green: 0.090, blue: 0.098)
    /// 한 단계 더 떠 있는 표면 (모달, 컴포저).
    static let bgFloat   = Color(red: 0.125, green: 0.125, blue: 0.137)

    static let inkPrimary   = Color(red: 0.961, green: 0.961, blue: 0.969)
    static let inkSecondary = Color(red: 0.612, green: 0.612, blue: 0.643)
    static let inkTertiary  = Color(red: 0.361, green: 0.361, blue: 0.388)

    /// 모든 카드 구분선·외곽 hairline.
    static let hairline = Color.white.opacity(0.07)
    /// 한 단계 더 흐릿한 구분선 (메타 위 등).
    static let hairlineSoft = Color.white.opacity(0.04)

    /// Scoor 브랜드 레드 — DesignTokens.primaryColor와 일치.
    static var accent: Color { DesignTokens.primaryColor }

    /// LIVE 인디케이터·번아웃 등 “경고/뜨거움” 톤.
    static let hot   = Color(red: 1.000, green: 0.396, blue: 0.376)
    /// 회복·차분 — 청록.
    static let cool  = Color(red: 0.435, green: 0.694, blue: 0.776)
    /// 밤·외로움 — 깊은 청보라.
    static let night = Color(red: 0.529, green: 0.553, blue: 0.749)
}

// MARK: - Score Tone

/// 점수대별 ‘색’만 정의. 시네마틱 후광·그라데이션은 사용하지 않는다.
enum ScoreTone: Equatable {
    case glow   // 86~100 — 브랜드 레드 (피크)
    case warm   // 71~85
    case soft   // 51~70
    case dim    // 31~50
    case deep   //  0~30

    static func from(score: Int) -> ScoreTone {
        switch score {
        case 86...:   return .glow
        case 71...85: return .warm
        case 51...70: return .soft
        case 31...50: return .dim
        default:      return .deep
        }
    }

    /// 점수 숫자/배지에 들어가는 메인 색.
    var primary: Color {
        switch self {
        case .glow: return ScoorPalette.accent
        case .warm: return Color(red: 0.949, green: 0.616, blue: 0.443)
        case .soft: return ScoorPalette.inkPrimary
        case .dim:  return ScoorPalette.inkSecondary
        case .deep: return ScoorPalette.night
        }
    }

    /// 점수 배지 배경 — 매우 옅게.
    var chipBackground: Color {
        primary.opacity(0.12)
    }
}

// MARK: - Typography

enum ScoorType {
    /// 본문 한 줄 감정 — 텍스트 우선 피드의 주인공.
    static var body: Font {
        .system(size: 15.5, weight: .regular, design: .default)
    }

    /// 닉네임.
    static var name: Font {
        .system(size: 13.5, weight: .semibold)
    }

    /// 메타 (도시 · 시간 · 라벨).
    static var meta: Font {
        .system(size: 12, weight: .medium)
    }

    /// 점수 배지.
    static func scoreBadge(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// 섹션 라벨.
    static var sectionLabel: Font {
        .system(size: 10.5, weight: .bold)
    }

    /// 액션 카운트.
    static var actionCount: Font {
        .system(size: 12.5, weight: .medium)
    }

    /// 필터·태그 칩.
    static var chip: Font {
        .system(size: 12.5, weight: .semibold)
    }
}

// MARK: - Time formatter

enum RelativeTime {
    static func short(from date: Date, now: Date = Date()) -> String {
        let s = Int(now.timeIntervalSince(date))
        if s < 60       { return "\(max(s, 1))초" }
        let m = s / 60
        if m < 60       { return "\(m)분" }
        let h = m / 60
        if h < 24       { return "\(h)시간" }
        let d = h / 24
        if d < 7        { return "\(d)일" }
        return "\(d / 7)주"
    }
}

// MARK: - Number formatter

enum CompactCount {
    /// 1,200 → "1.2k", 12,400 → "12k". 0이면 빈 문자열.
    static func format(_ n: Int) -> String {
        if n <= 0 { return "" }
        if n < 1_000 { return "\(n)" }
        if n < 10_000 {
            let k = Double(n) / 1_000.0
            return String(format: "%.1fk", k)
        }
        return "\(n / 1_000)k"
    }
}
