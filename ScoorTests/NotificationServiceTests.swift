//
//  NotificationServiceTests.swift
//  ScoorTests
//
//  MockNotificationService 기반 설정/스케줄 로직 테스트.
//  (실제 UNUserNotificationCenter 권한/스케줄은 시뮬레이터 스크린샷으로 검증)
//

import XCTest
@testable import Scoor

final class NotificationServiceTests: XCTestCase {

    /// 테스트마다 격리된 UserDefaults suite.
    private func freshDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.scoor.notif.\(name)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    // MARK: - Defaults

    func testDefaultEnabledAndNinePM() {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d)
        XCTAssertTrue(svc.isEnabled, "기본값은 켜짐이어야 한다")
        XCTAssertEqual(svc.reminderTime.hour, 21)
        XCTAssertEqual(svc.reminderTime.minute, 0)
    }

    // MARK: - Toggle off / on

    func testToggleOffDisablesAndClearsSchedule() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d)
        await svc.setEnabled(false)
        XCTAssertFalse(svc.isEnabled)
        XCTAssertNil(svc.nextReminderDate(), "꺼지면 다음 리마인더가 없어야 한다")
        XCTAssertTrue(svc.lastClearedSchedule)
    }

    func testToggleOnSchedulesWhenAuthorized() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d, authorizationStatus: .authorized)
        await svc.setEnabled(false)
        await svc.setEnabled(true)
        XCTAssertTrue(svc.isEnabled)
        XCTAssertGreaterThan(svc.scheduleCount, 0)
        XCTAssertNotNil(svc.nextReminderDate())
    }

    // MARK: - Permission granted / denied

    func testRequestAuthorizationGranted() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d, grantAuthorization: true, authorizationStatus: .notDetermined)
        let granted = await svc.requestAuthorization()
        XCTAssertTrue(granted)
        let status = await svc.currentAuthorizationStatus()
        XCTAssertEqual(status, .authorized)
    }

    func testRequestAuthorizationDeniedDoesNotSchedule() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d, grantAuthorization: false, authorizationStatus: .notDetermined)
        let granted = await svc.requestAuthorization()
        XCTAssertFalse(granted)
        await svc.refreshSchedule()
        XCTAssertEqual(svc.scheduleCount, 0, "권한 거부 시 스케줄이 잡히면 안 된다")
        let active = await svc.isActive()
        XCTAssertFalse(active)
    }

    // MARK: - Time change persists

    func testTimeChangePersists() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d)
        await svc.setReminderTime(DateComponents(hour: 7, minute: 30))
        XCTAssertEqual(svc.reminderTime.hour, 7)
        XCTAssertEqual(svc.reminderTime.minute, 30)
    }

    // MARK: - App relaunch reads stored prefs

    func testRelaunchReadsStoredPreferences() async {
        let suite = "test.scoor.notif.relaunch"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)

        // 1회차: 시각 변경 + 끄기.
        let first = MockNotificationService(defaults: d)
        await first.setReminderTime(DateComponents(hour: 8, minute: 15))
        await first.setEnabled(false)

        // "재시작": 같은 suite로 새 인스턴스.
        let second = MockNotificationService(defaults: d)
        XCTAssertFalse(second.isEnabled, "끔 상태가 재시작 후에도 유지")
        XCTAssertEqual(second.reminderTime.hour, 8)
        XCTAssertEqual(second.reminderTime.minute, 15)
    }

    // MARK: - nextReminderDate math

    func testNextReminderDateIsInFutureAndMatchesTime() async {
        let d = freshDefaults()
        let svc = MockNotificationService(defaults: d)
        await svc.setReminderTime(DateComponents(hour: 21, minute: 0))
        guard let date = svc.nextReminderDate() else { return XCTFail("nextReminderDate nil") }
        XCTAssertGreaterThan(date, Date())
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        XCTAssertEqual(comps.hour, 21)
        XCTAssertEqual(comps.minute, 0)
    }
}
