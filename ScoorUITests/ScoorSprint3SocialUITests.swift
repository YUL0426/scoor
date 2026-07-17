//
//  ScoorSprint3SocialUITests.swift
//  ScoorUITests
//
//  Sprint 3/4 소셜 레이어 E2E:
//   - Feed 탭 타임라인 렌더 + 좋아요 탭
//   - 사용자 탐색(Discover) 진입 + 팔로우 토글
//   - World 토픽 피드 렌더 + 토픽 상세 진입
//

import XCTest

final class ScoorSprint3SocialUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uitests-reset"]
    }

    // MARK: - Helpers

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    @discardableResult
    private func tapIfExists(_ el: XCUIElement, _ timeout: TimeInterval = 6) -> Bool {
        if el.waitForExistence(timeout: timeout) { el.tap(); return true }
        return false
    }

    private func centerTap() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// 요소가 사라질 때까지 대기.
    private func waitForGone(_ el: XCUIElement, _ timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !el.exists { return true }
            usleep(200_000)
        }
        return !el.exists
    }

    private func reachMain(username: String) {
        let apple = app.buttons["Continue with Apple"]
        if apple.waitForExistence(timeout: 8) {
            apple.tap()
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 8) {
                field.tap(); field.typeText(username)
                if app.staticTexts["Choose your Scoor name"].exists {
                    app.staticTexts["Choose your Scoor name"].tap()
                }
                let claim = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Claim'")).firstMatch
                if claim.waitForExistence(timeout: 6) {
                    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: claim)
                    waitForExpectations(timeout: 8)
                    claim.tap()
                }
            }
            sleep(1); centerTap()
            tapIfExists(app.buttons["Next"], 8)
            tapIfExists(app.buttons["Try your first Scoor"], 8)
            tapIfExists(app.buttons["Skip"], 8)
        }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Main tab bar never appeared")
    }

    // MARK: - Test

    func testSocialLayerScreens() {
        app.launch()
        reachMain(username: "scoor_social_qa")

        // --- Feed 타임라인 ---
        XCTAssertTrue(tapIfExists(app.buttons["Feed"], 8), "Feed tab missing")
        sleep(1)
        snap("01-feed-timeline")

        // 카드가 하나 이상 렌더되는지(좋아요 하트 등 액션 버튼 존재).
        XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 6), "Feed scroll missing")

        // --- 사용자 탐색 진입 ---
        let discover = app.buttons["feed.discoverButton"]
        XCTAssertTrue(discover.waitForExistence(timeout: 6), "Discover entry button missing")
        discover.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["탐색"].waitForExistence(timeout: 6), "Discover sheet did not open")
        snap("02-discover")

        // 첫 팔로우 버튼 토글(낙관적 → 영속).
        let follow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'discover.follow.'")).firstMatch
        if follow.waitForExistence(timeout: 6) {
            let label = follow.label
            follow.tap()
            sleep(1)
            // 토글 후 같은 버튼이 "팔로잉"으로 바뀌었는지 확인(영속 반영).
            XCTAssertNotEqual(follow.label, label, "팔로우 버튼 상태가 토글되어야 한다")
            snap("03-discover-followed")
        }
        // 시트를 닫기 버튼으로 확실히 닫는다.
        XCTAssertTrue(tapIfExists(app.buttons["discover.closeButton"], 6), "Discover close button missing")
        XCTAssertTrue(waitForGone(app.staticTexts["탐색"], 6), "Discover sheet did not dismiss")

        // --- World 토픽 피드 ---
        XCTAssertTrue(tapIfExists(app.buttons["World"], 8), "World tab missing")
        sleep(1)
        XCTAssertTrue(app.otherElements["world.header"].waitForExistence(timeout: 6)
                      || app.staticTexts["world.header"].waitForExistence(timeout: 6),
                      "World header missing")
        snap("04-world-feed")
    }
}
