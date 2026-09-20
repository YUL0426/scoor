import XCTest

/// Run with SUPABASE_HOST= SUPABASE_ANON_KEY= to keep review QA local.
final class ScoorEnglishReviewUITests: XCTestCase {
    private let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testEnglishSignupPrivateRecordAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset"] + english
        app.launch()
        let apple = app.buttons["signup-apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 15))
        XCTAssertEqual(apple.label, "Continue with Apple")
        inspect(app, "en-entry")
        for (kind, title) in [("terms", "Terms of Service"), ("privacy", "Privacy Notice")] {
            let link = app.buttons["legal-read-\(kind)"]
            for _ in 0..<5 where !link.isHittable { app.swipeUp() }
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            inspect(app, "en-\(kind)")
            app.buttons["Done"].tap()
        }
        for _ in 0..<5 where !apple.isHittable { app.swipeDown() }
        apple.tap()
        XCTAssertTrue(app.buttons["main-tab-Home"].waitForExistence(timeout: 15))
        inspect(app, "en-home-empty")
        for (tab, name) in [("main-tab-World", "en-world-empty"), ("main-tab-알림", "en-notifications")] {
            app.buttons[tab].tap()
            inspect(app, name)
        }
        app.buttons["main-tab-Home"].tap()
        app.buttons["main-add-score"].tap()
        XCTAssertTrue(app.buttons["score-keypad-digit-7"].waitForExistence(timeout: 5))
        inspect(app, "en-score-input")
        app.buttons["score-keypad-digit-7"].tap()
        app.buttons["score-keypad-digit-3"].tap()
        let reason = app.textFields["reason-field"].exists ? app.textFields["reason-field"] : app.textViews["reason-field"]
        reason.tap()
        reason.typeText("A good day for a walk")
        app.buttons["reason-done-button"].tap()
        app.buttons["score-keypad-submit"].tap()
        XCTAssertTrue(app.buttons["main-tab-My Page"].waitForExistence(timeout: 10))
        app.buttons["main-tab-My Page"].tap()
        let today = app.buttons["mypage-today-card"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(today.label.contains("73"), today.label)
        inspect(app, "en-record-saved")

        app.terminate()
        app.launchArguments = english
        app.launch()
        XCTAssertTrue(app.buttons["main-tab-My Page"].waitForExistence(timeout: 15))
        app.buttons["main-tab-My Page"].tap()
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        XCTAssertTrue(today.label.contains("73"), today.label)
        today.tap()
        XCTAssertTrue(reason.waitForExistence(timeout: 5))
        XCTAssertEqual(reason.value as? String, "A good day for a walk")
        inspect(app, "en-record-restored")
        app.buttons["score-back-button"].tap()
        XCTAssertTrue(app.buttons["score-back-button"].waitForNonExistence(timeout: 5))
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        inspect(app, "en-settings-account")
        let language = app.buttons["settings-language-button"]
        for _ in 0..<5 where !language.exists { app.swipeUp() }
        XCTAssertTrue(language.exists)
        inspect(app, "en-settings")
    }

    func testEnglishWorldAndKeypadReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-appstore-screenshot-fixture", "-appstore-world-screenshot-fixture"] + english
        app.launch()
        if !app.buttons["main-tab-World"].waitForExistence(timeout: 3) {
            XCTAssertTrue(app.buttons["signup-apple"].waitForExistence(timeout: 15))
            app.buttons["signup-apple"].tap()
        }
        XCTAssertTrue(app.buttons["main-tab-World"].waitForExistence(timeout: 15))
        app.buttons["main-tab-World"].tap()
        let topic = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "A four-day workweek?")).firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        inspect(app, "en-world")
        topic.tap()
        XCTAssertTrue(app.buttons["topic-enter-score"].waitForExistence(timeout: 8))
        inspect(app, "en-topic")
        app.buttons["topic-enter-score"].tap()
        for digit in 0...9 {
            let key = app.buttons["score-keypad-digit-\(digit)"]
            XCTAssertTrue(key.waitForExistence(timeout: 3))
            XCTAssertTrue(key.isHittable)
            XCTAssertGreaterThanOrEqual(key.frame.height, 44)
            XCTAssertTrue(app.windows.firstMatch.frame.contains(key.frame), "Key \(digit): \(key.frame), window: \(app.windows.firstMatch.frame)")
        }
        app.buttons["score-keypad-digit-7"].tap()
        app.buttons["score-keypad-digit-8"].tap()
        XCTAssertTrue(app.buttons["score-keypad-submit"].isEnabled)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Disagree", "Agree")).firstMatch.exists)
        inspect(app, "en-topic-input")
    }

    private func inspect(_ app: XCUIApplication, _ name: String) {
        // Let transitions finish before checking what a reviewer can see.
        Thread.sleep(forTimeInterval: 0.8)
        let viewport = app.windows.firstMatch.frame
        for query in [app.staticTexts, app.buttons] {
            for element in query.allElementsBoundByIndex {
                let frame = element.frame
                guard frame.width > 0, frame.height > 0, viewport.intersects(frame) else { continue }
                XCTAssertNil(element.label.range(of: "[가-힣]", options: .regularExpression), "\(name): \(element.label)")
            }
        }
        // App screenshots crop incorrectly in iPad's scaled iPhone compatibility mode.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
