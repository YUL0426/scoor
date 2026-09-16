import XCTest

final class ScoorLegalConsentUITests: XCTestCase {
    private func launch(language: String = "en", extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-AppleLanguages", "(\(language))", "-AppleLocale", language == "ko" ? "ko_KR" : "en_US"] + extra
        app.launch()
        return app
    }

    func testAppleFinishesSignupWithoutFormsOrRequiredCheckboxes() {
        let app = launch()
        let apple = app.buttons["signup-apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 10))
        XCTAssertTrue(apple.isEnabled)
        XCTAssertTrue(app.buttons["signup-google"].isHittable)
        XCTAssertTrue(app.staticTexts["account-entry-notice"].isHittable)
        for id in ["legal-terms", "legal-privacy", "legal-account-data", "legal-age"] {
            XCTAssertFalse(app.switches[id].exists)
        }
        apple.tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Choose your Scoor name"].exists)
        XCTAssertFalse(app.buttons["legal-continue"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-uitests-reset" }
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["signup-apple"].exists)
    }

    func testGoogleFinishesSignupWithoutForms() {
        let app = launch()
        let google = app.buttons["signup-google"]
        XCTAssertTrue(google.waitForExistence(timeout: 10))
        google.tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["legal-continue"].exists)
    }

    func testCancelledProviderStaysOnEntryScreen() {
        let app = launch(extra: ["-uitests-auth-cancel"])
        let apple = app.buttons["signup-apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 10))
        apple.tap()
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Home"].exists)
        XCTAssertFalse(app.buttons["legal-continue"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    func testDocumentsDoNotCreateAnAccount() {
        let app = launch()
        XCTAssertTrue(app.buttons["signup-apple"].waitForExistence(timeout: 10))
        for (id, title) in [("terms", "Terms of Service"), ("privacy", "Privacy Notice")] {
            let link = app.buttons["legal-read-\(id)"]
            for _ in 0..<4 where !link.isHittable { app.scrollViews["account-entry-scroll"].swipeUp() }
            XCTAssertTrue(link.isHittable)
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            app.buttons["Done"].tap()
            XCTAssertTrue(app.buttons["signup-apple"].exists)
            XCTAssertFalse(app.buttons["Home"].exists)
        }
    }

    func testExampleStoriesRotateAndPauseWithoutSigningIn() {
        let app = launch(language: "ko")
        XCTAssertTrue(app.buttons["signup-apple"].waitForExistence(timeout: 10))
        let story = app.descendants(matching: .any).matching(identifier: "legal-story-tokyo").firstMatch
        XCTAssertTrue(story.waitForExistence(timeout: 8))
        app.buttons["legal-story-pause"].tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Social signup — Korean split layout"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let changesWhilePaused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: story)
        changesWhilePaused.isInverted = true
        wait(for: [changesWhilePaused], timeout: 6)
        XCTAssertTrue(app.buttons["signup-apple"].isEnabled)
        XCTAssertFalse(app.buttons["Home"].exists)
    }

    func testLargeTextKeepsLoginAndDocumentsReachable() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let scroll = app.scrollViews["account-entry-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for id in ["signup-apple", "signup-google", "legal-read-terms", "legal-read-privacy"] {
            let button = app.buttons[id]
            for _ in 0..<12 where !button.isHittable { scroll.swipeUp() }
            XCTAssertTrue(button.isHittable, id)
        }
    }

    func testFailedReceiptCanRetryWithoutAnotherProviderLogin() {
        let app = launch(extra: ["-uitests-consent-recovery"])
        let next = app.buttons["legal-continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: next)
        wait(for: [ready], timeout: 5)
        XCTAssertFalse(app.staticTexts["account-entry-error"].exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["account-entry-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(app.staticTexts["consent-recovery-complete"].waitForExistence(timeout: 5))
    }
}
