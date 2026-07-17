//
//  NotificationService.swift
//  Scoor
//
//  일일 리마인더(로컬 알림) 시스템.
//
//  - 사용자 설정(켜짐/꺼짐, 리마인더 시각)은 UserDefaults에 "scoor.notif.*" 키로 저장.
//  - 단 하나의 반복 UNCalendarNotificationTrigger("scoor.dailyReminder")를 스케줄.
//  - 권한 거부 상태도 안전하게 처리 — 설정값은 유지하되 UI가 "설정에서 켜기"를 안내.
//
//  기본값: 켜짐(enabled=true), 21:00.
//

import Foundation
import UserNotifications

// MARK: - Preference storage (real / mock 공용)

enum NotificationPrefs {
    static let enabledKey = "scoor.notif.enabled"
    static let hourKey    = "scoor.notif.hour"
    static let minuteKey  = "scoor.notif.minute"

    static let defaultHour = 21
    static let defaultMinute = 0

    /// 최초 실행 시 기본값(켜짐, 21:00) 등록 — `bool(forKey:)`가 false로 떨어지지 않게.
    static func registerDefaults(_ defaults: UserDefaults) {
        defaults.register(defaults: [
            enabledKey: true,
            hourKey: defaultHour,
            minuteKey: defaultMinute
        ])
    }
}

// MARK: - Copy

enum NotificationCopy {
    static let title = String(localized: "Today's Scoor")
    static let body  = String(localized: "What score would you give today?")
    static let requestId = "scoor.dailyReminder"
}

// MARK: - Protocol

// 이 서비스들은 UI 상태를 갖지 않고 UserDefaults / UNUserNotificationCenter(둘 다 thread-safe)만
// 다루므로 nonisolated로 둔다. (프로젝트 기본 isolation이 MainActor라서 명시 필요.)
// 또한 MainActor-isolated deinit이 백그라운드 스레드에서 해제될 때 발생하는
// swift 동시성 런타임 크래시(swift_task_deinitOnExecutorMainActorBackDeploy)를 피한다.
nonisolated protocol NotificationServiceProtocol {
    /// 사용자가 리마인더를 켰는지 (시스템 권한과 별개의 앱 내 설정).
    var isEnabled: Bool { get }
    /// 리마인더 시각(시/분).
    var reminderTime: DateComponents { get }

    /// 현재 시스템 알림 권한 상태.
    func currentAuthorizationStatus() async -> UNAuthorizationStatus
    /// 권한 요청. 허용되면 true.
    @discardableResult
    func requestAuthorization() async -> Bool
    /// 앱 내 켜짐/꺼짐 설정 변경 + 스케줄 갱신.
    func setEnabled(_ enabled: Bool) async
    /// 리마인더 시각 변경 + 스케줄 갱신.
    func setReminderTime(_ time: DateComponents) async
    /// 다음에 울릴 리마인더 시각 (꺼져 있으면 nil).
    func nextReminderDate() -> Date?
    /// 저장된 설정에 맞춰 스케줄을 다시 맞춘다 (앱 시작 시 호출).
    func refreshSchedule() async
}

extension NotificationServiceProtocol {
    /// 켜짐 + 권한 허용 상태일 때만 실제로 알림이 울린다.
    func isActive() async -> Bool {
        guard isEnabled else { return false }
        return await currentAuthorizationStatus() == .authorized
    }

    /// 사용자가 점수를 기록한 직후 호출되는 연계 훅(Daily Scoor 플로우).
    /// 오늘 기록을 마쳤다면 이미 떠 있는 "오늘의 Scoor" 배너를 정리하고
    /// 저장된 설정에 맞춰 반복 스케줄을 다시 맞춘다. 기본 구현은 스케줄만
    /// 갱신 — 배너 정리는 시스템 센터를 다루는 구현체에서 오버라이드한다.
    ///
    /// 참고: 반복 트리거 특성상 "오늘 한 번만 건너뛰기"는 불가하므로,
    /// 이미 전달된 알림 제거 + 스케줄 동기화를 정책으로 채택한다.
    func handleScoreLogged(on date: Date) async {
        await refreshSchedule()
    }
}

// MARK: - Real implementation

nonisolated final class LocalNotificationService: NotificationServiceProtocol {

    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults

    init(center: UNUserNotificationCenter = .current(), defaults: UserDefaults = .standard) {
        self.center = center
        self.defaults = defaults
        NotificationPrefs.registerDefaults(defaults)
    }

    var isEnabled: Bool { defaults.bool(forKey: NotificationPrefs.enabledKey) }

    var reminderTime: DateComponents {
        DateComponents(
            hour: defaults.integer(forKey: NotificationPrefs.hourKey),
            minute: defaults.integer(forKey: NotificationPrefs.minuteKey)
        )
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func setEnabled(_ enabled: Bool) async {
        defaults.set(enabled, forKey: NotificationPrefs.enabledKey)
        await refreshSchedule()
    }

    func setReminderTime(_ time: DateComponents) async {
        defaults.set(time.hour ?? NotificationPrefs.defaultHour, forKey: NotificationPrefs.hourKey)
        defaults.set(time.minute ?? NotificationPrefs.defaultMinute, forKey: NotificationPrefs.minuteKey)
        await refreshSchedule()
    }

    func nextReminderDate() -> Date? {
        guard isEnabled else { return nil }
        return Calendar.current.nextDate(
            after: Date(),
            matching: reminderTime,
            matchingPolicy: .nextTime
        )
    }

    func refreshSchedule() async {
        // 항상 기존 요청부터 제거 — 중복/유령 스케줄 방지.
        center.removePendingNotificationRequests(withIdentifiers: [NotificationCopy.requestId])

        // 꺼져 있거나 권한이 없으면 스케줄하지 않는다.
        guard isEnabled else { return }
        let status = await currentAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = NotificationCopy.title
        content.body = NotificationCopy.body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: reminderTime, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationCopy.requestId,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    /// 오늘 기록 완료 시: 이미 전달된 리마인더 배너를 제거하고 스케줄을 동기화.
    /// 과거 날짜 보정 입력에는 반응하지 않는다(미래 리마인더와 무관).
    func handleScoreLogged(on date: Date) async {
        if Calendar.current.isDateInToday(date) {
            center.removeDeliveredNotifications(withIdentifiers: [NotificationCopy.requestId])
        }
        await refreshSchedule()
    }
}

// MARK: - Mock (previews / tests)

/// UNUserNotificationCenter를 건드리지 않는 인메모리/UserDefaults 기반 목.
/// 권한 결과와 스케줄 횟수를 검사할 수 있다.
nonisolated final class MockNotificationService: NotificationServiceProtocol {

    private let defaults: UserDefaults
    /// requestAuthorization()이 돌려줄 값(테스트에서 조정).
    var grantAuthorization: Bool
    /// 현재 권한 상태(테스트에서 조정).
    var authorizationStatus: UNAuthorizationStatus
    /// refreshSchedule이 실제 스케줄을 건 횟수(검증용).
    private(set) var scheduleCount = 0
    /// 마지막으로 스케줄이 제거되었는지.
    private(set) var lastClearedSchedule = false
    /// handleScoreLogged가 "오늘 배너 정리"를 수행한 횟수(검증용).
    private(set) var clearedDeliveredCount = 0

    init(
        defaults: UserDefaults = .standard,
        grantAuthorization: Bool = true,
        authorizationStatus: UNAuthorizationStatus = .authorized
    ) {
        self.defaults = defaults
        self.grantAuthorization = grantAuthorization
        self.authorizationStatus = authorizationStatus
        NotificationPrefs.registerDefaults(defaults)
    }

    var isEnabled: Bool { defaults.bool(forKey: NotificationPrefs.enabledKey) }

    var reminderTime: DateComponents {
        DateComponents(
            hour: defaults.integer(forKey: NotificationPrefs.hourKey),
            minute: defaults.integer(forKey: NotificationPrefs.minuteKey)
        )
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus { authorizationStatus }

    @discardableResult
    func requestAuthorization() async -> Bool {
        authorizationStatus = grantAuthorization ? .authorized : .denied
        return grantAuthorization
    }

    func setEnabled(_ enabled: Bool) async {
        defaults.set(enabled, forKey: NotificationPrefs.enabledKey)
        await refreshSchedule()
    }

    func setReminderTime(_ time: DateComponents) async {
        defaults.set(time.hour ?? NotificationPrefs.defaultHour, forKey: NotificationPrefs.hourKey)
        defaults.set(time.minute ?? NotificationPrefs.defaultMinute, forKey: NotificationPrefs.minuteKey)
        await refreshSchedule()
    }

    func nextReminderDate() -> Date? {
        guard isEnabled else { return nil }
        return Calendar.current.nextDate(after: Date(), matching: reminderTime, matchingPolicy: .nextTime)
    }

    func refreshSchedule() async {
        if isEnabled && authorizationStatus == .authorized {
            scheduleCount += 1
            lastClearedSchedule = false
        } else {
            lastClearedSchedule = true
        }
    }

    func handleScoreLogged(on date: Date) async {
        if Calendar.current.isDateInToday(date) {
            clearedDeliveredCount += 1
        }
        await refreshSchedule()
    }
}
