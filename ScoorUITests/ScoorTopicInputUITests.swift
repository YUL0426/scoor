import XCTest

final class ScoorTopicInputUITests: XCTestCase {
    func testMyPageRepostsTabShowsEmptyState() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-appstore-screenshot-fixture", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        if app.buttons["signup-apple"].waitForExistence(timeout: 3) { app.buttons["signup-apple"].tap() }
        XCTAssertTrue(app.buttons["main-tab-My Page"].waitForExistence(timeout: 12))
        app.buttons["main-tab-My Page"].tap()
        let reposts = app.buttons["mypage-section-리포스트"]
        XCTAssertTrue(reposts.waitForExistence(timeout: 5))
        reposts.tap()
        XCTAssertTrue(app.staticTexts["아직 리포스트한 글이 없어요"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "mypage-reposts-tab"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testKeypadAndCommentDoNotOverlap() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-appstore-screenshot-fixture", "-appstore-world-screenshot-fixture", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        if app.buttons["signup-apple"].waitForExistence(timeout: 3) { app.buttons["signup-apple"].tap() }
        XCTAssertTrue(app.buttons["main-tab-World"].waitForExistence(timeout: 12))
        app.buttons["main-tab-World"].tap()
        let topic = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "주 4일 근무, 어떻게 생각해?")).firstMatch
        XCTAssertTrue(topic.waitForExistence(timeout: 10))
        topic.tap()
        let enter = app.buttons["topic-enter-score"]
        XCTAssertTrue(enter.waitForExistence(timeout: 8))
        enter.tap()
        for n in 0...9 {
            let key = app.buttons["score-keypad-digit-\(n)"]
            XCTAssertTrue(key.waitForExistence(timeout: 3))
            XCTAssertTrue(key.isHittable)
            XCTAssertGreaterThanOrEqual(key.frame.height, 44)
            XCTAssertLessThan(key.frame.maxY, app.frame.maxY)
        }
        XCTAssertFalse(app.staticTexts["🔥"].exists)
        app.buttons["score-keypad-digit-7"].tap()
        app.buttons["score-keypad-digit-8"].tap()
        XCTAssertTrue(app.buttons["score-keypad-submit"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "topic-keypad-fixed"
        attachment.lifetime = .keepAlways
        add(attachment)
        let comment = app.textFields["topic-score-comment"].exists ? app.textFields["topic-score-comment"] : app.textViews["topic-score-comment"]
        comment.tap()
        comment.typeText("좋아요")
        XCTAssertFalse(app.buttons["score-keypad-digit-7"].exists)
        app.buttons["완료"].tap()
        XCTAssertTrue(app.buttons["score-keypad-digit-7"].waitForExistence(timeout: 3))
    }
}
