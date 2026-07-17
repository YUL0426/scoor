//
//  StreakService.swift
//  Scoor
//
//  연속 기록(streak) 계산의 단일 진실 공급원(single source of truth).
//
//  이전에는 HomeViewModel / StatsViewModel / MyPageView 세 곳에서
//  각자 streak를 계산했고, "오늘 아직 기록 전" 케이스에서 동작이 달랐다.
//  이제 모든 화면이 이 서비스를 호출한다.
//
//  규칙: streak는 "오늘이 끝나기 전까지 살아있다".
//  즉 어제 기록이 있으면 오늘 기록이 아직 없어도 streak는 유지된다.
//  (Home/Stats의 기존 동작을 표준으로 채택, MyPage가 여기에 맞춰진다.)
//
//  streak는 이미 로드된 점수에서 파생되는 순수 계산이므로
//  상태를 갖지 않는 enum 네임스페이스로 둔다 — 주입 불필요, 어디서든 호출 가능.
//

import Foundation

/// 현재/최장 streak를 함께 담는 결과값.
struct StreakResult: Equatable {
    let current: Int
    let longest: Int

    static let zero = StreakResult(current: 0, longest: 0)
}

enum StreakService {

    /// 현재 연속 기록 일수.
    ///
    /// `today`를 달력상 하루의 시작으로 정규화한 뒤, 오늘 칸이 비어 있으면
    /// 하루 뒤로 물러서서(어제부터) 연속된 기록 일수를 거꾸로 센다.
    /// 첫 공백에서 멈춘다.
    ///
    /// - Parameters:
    ///   - entriesByDay: `startOfDay` 키로 인덱싱된 일별 점수(예: `ScoreCalendarIndex.entriesByDay`).
    ///   - today: 기준이 되는 "오늘". 테스트에서 주입 가능.
    ///   - calendar: 날짜 정규화에 쓸 달력. 타임존 엣지 테스트를 위해 주입 가능.
    static func currentStreak(
        entriesByDay: [Date: ScoreEntry],
        today: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !entriesByDay.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: today)

        // 오늘 아직 기록이 없으면 어제부터 센다 — streak는 오늘이 끝날 때까지 살아있다.
        if entriesByDay[day] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while entriesByDay[day] != nil {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// 기록 전체에서 가장 길었던 연속 기록 일수.
    ///
    /// 기록된 모든 날을 정렬해 인접한 날짜(정확히 1일 간격)의 가장 긴 구간을 찾는다.
    /// "오늘" 개념과 무관하며, 미래의 "최고 기록" 표시에 쓰인다.
    static func longestStreak(
        entriesByDay: [Date: ScoreEntry],
        calendar: Calendar = .current
    ) -> Int {
        guard !entriesByDay.isEmpty else { return 0 }

        // 키는 이미 startOfDay여야 하지만, 방어적으로 다시 정규화 후 중복 제거.
        let days = Set(entriesByDay.keys.map { calendar.startOfDay(for: $0) }).sorted()

        var longest = 1
        var run = 1
        for i in 1..<days.count {
            let prev = days[i - 1]
            let cur = days[i]
            if let next = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(next, inSameDayAs: cur) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }

    /// 현재 + 최장 streak를 한 번에.
    static func streak(
        entriesByDay: [Date: ScoreEntry],
        today: Date,
        calendar: Calendar = .current
    ) -> StreakResult {
        StreakResult(
            current: currentStreak(entriesByDay: entriesByDay, today: today, calendar: calendar),
            longest: longestStreak(entriesByDay: entriesByDay, calendar: calendar)
        )
    }
}
