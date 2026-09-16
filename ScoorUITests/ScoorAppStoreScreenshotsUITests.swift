//
//  ScoorAppStoreScreenshotsUITests.swift
//  ScoorUITests
//
//  DEBUG-only App Store capture harness. It launches the app with the
//  in-memory private-journal fixture, so these tests never authenticate or
//  sync against Supabase and never require network access.
//

import XCTest

final class ScoorAppStoreScreenshotsUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testKoreanScreenshots() {
        captureStoreScreens(language: "ko", locale: "ko_KR")
    }

    func testEnglishScreenshots() {
        captureStoreScreens(language: "en", locale: "en_US")
    }

    /// Real World views, backed by an isolated local HTTP fixture. No publishing.
    func testKoreanWorldStoryScreenshots() {
        captureWorldStoryScreens(language: "ko", locale: "ko_KR")
    }

    func testEnglishWorldStoryScreenshots() {
        captureWorldStoryScreens(language: "en", locale: "en_US")
    }

    private func captureWorldStoryScreens(language: String, locale: String) {
        let isKorean = language == "ko"
        app.launchArguments = [
            "-uitests-reset", "-appstore-screenshot-fixture", "-appstore-world-screenshot-fixture",
            "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-AppleInterfaceStyle", "Dark"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        XCTAssertTrue(app.buttons["main-add-score"].waitForExistence(timeout: 12))
        captureScoreEntry(named: "store-\(language)-01-score", expectedReason: isKorean ? "오랜만에 여유 있는 저녁" : "An unhurried evening")
        capturePersonalRecords(named: "store-\(language)-05-records")

        app.buttons["main-tab-World"].tap()
        let topic = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", isKorean ? "주 4일 근무, 어떻게 생각해?" : "A four-day workweek?")).firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[isKorean ? "기술이 시간을 돌려준다면, 그 시간은 사람에게." : "If tech gives us time back, let's spend it on people."].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["preview-content-banner"].exists)
        snap("store-\(language)-02-world")

        topic.tap()
        XCTAssertTrue(app.staticTexts[isKorean ? "글로벌 Scoor" : "GLOBAL SCOOR"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts[isKorean ? "하루의 여유가 생기면, 일할 때 더 집중할 수 있을 것 같아요." : "A little more time to live. A little more energy to give."].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["7"].exists, "The sample has exactly seven topic reactions")
        XCTAssertFalse(app.staticTexts["국가별 감정 비교"].exists, "Do not capture the legacy preview-only UI")
        snap("store-\(language)-03-perspectives")

        let lastReaction = app.staticTexts[isKorean ? "우리 팀에도 이런 선택지가 생겼으면!" : "I'd love to see our team give this a try!"]
        for _ in 0..<4 {
            if lastReaction.exists && lastReaction.frame.minY > app.frame.minY+80 && lastReaction.frame.maxY < app.frame.maxY-155 { break }
            app.scrollViews["world-topic-detail-scroll"].swipeUp(velocity: .slow)
        }
        // SwiftUI's full-screen CTA overlay makes isHittable false even for
        // visible text. Capture checks should assert visibility within the frame.
        XCTAssertTrue(lastReaction.exists && lastReaction.frame.minY > app.frame.minY+80
                      && lastReaction.frame.maxY < app.frame.maxY-155)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Scoor")).firstMatch.exists)
        snap("store-\(language)-04-connection")
    }

    // MARK: - Capture flow

    private func captureStoreScreens(language: String, locale: String) {
        app.launchArguments = [
            "-uitests-reset",
            "-appstore-screenshot-fixture",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-AppleInterfaceStyle", "Dark"
        ]
        XCUIDevice.shared.orientation = .portrait
        app.launch()

        XCTAssertTrue(app.buttons["main-add-score"].waitForExistence(timeout: 12),
                      "Fixture did not reach the main flow")

        captureScoreEntry(named: "store-\(language)-01-score", expectedReason: language == "ko" ? "오랜만에 여유 있는 저녁" : "An unhurried evening")
        capturePersonalRecords(named: "store-\(language)-02-records")
        captureStatistics(named: "store-\(language)-03-stats")
        captureCalendar(named: "store-\(language)-04-calendar")
    }

    /// Existing seeded today's score provides a visible, meaningful reason while
    /// leaving the native custom keypad on screen and the system keyboard hidden.
    private func captureScoreEntry(named name: String, expectedReason: String) {
        app.buttons["main-add-score"].tap()
        let keypad = app.descendants(matching: .any)["score-keypad"]
        XCTAssertTrue(keypad.waitForExistence(timeout: 8), "Custom score keypad did not appear")

        let reason = app.textFields["reason-field"]
        XCTAssertTrue(reason.waitForExistence(timeout: 5), "Seeded reason field did not appear")
        let hasReason = NSPredicate(format: "value == %@", expectedReason)
        expectation(for: hasReason, evaluatedWith: reason)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "System keyboard must not cover the native keypad")
        snap(name)

        app.buttons["score-back-button"].tap()
        XCTAssertTrue(app.buttons["main-add-score"].waitForExistence(timeout: 6))
    }

    private func capturePersonalRecords(named name: String) {
        app.buttons["main-tab-My Page"].tap()
        XCTAssertTrue(app.buttons["mypage-today-card"].waitForExistence(timeout: 8),
                      "My Page did not show the seeded private record")
        snap(name)
    }

    private func captureStatistics(named name: String) {
        app.buttons["mypage-section-통계"].tap()
        let period = app.buttons["stats-period-weekly"]
        XCTAssertTrue(period.waitForExistence(timeout: 6), "Statistics period selector did not appear")
        period.tap()
        XCTAssertTrue(app.descendants(matching: .any)["stats-trend-chart"].waitForExistence(timeout: 8),
                      "Trend chart did not receive the fixture history")
        snap(name)
    }

    private func captureCalendar(named name: String) {
        // Stable ID is independent of language. Tap the native disclosure chevron.
        let calendarDisclosure = app.descendants(matching: .any)["stats-calendar-disclosure"]
        for _ in 0..<6 {
            if calendarDisclosure.exists && calendarDisclosure.isHittable { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(calendarDisclosure.exists && calendarDisclosure.isHittable,
                      "Recording calendar disclosure did not appear")
        calendarDisclosure.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()

        // The calendar uses a LazyVGrid below the fold. Reveal it before querying day cells.
        let day = Calendar.current.component(.day, from: Date())
        let todayCell = app.buttons["calendar-day-\(day)"]
        for _ in 0..<4 {
            app.scrollViews.firstMatch.swipeUp()
            if todayCell.exists && todayCell.isHittable { break }
        }
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5),
                      "Current month calendar did not expand")
        let last = Calendar.current.range(of: .day, in: .month, for: Date())!.count
        let lastCell = app.buttons["calendar-day-\(last)"]
        for _ in 0..<4 {
            if lastCell.exists && lastCell.frame.maxY < app.frame.maxY - 100 { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        snap(name)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
