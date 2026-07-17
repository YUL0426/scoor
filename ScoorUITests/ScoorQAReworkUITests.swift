//
//  ScoorQAReworkUITests.swift
//  ScoorUITests
//
//  QA 리워크 라운드 검증 스크린샷:
//   ① Home 전체 현지화(ko 강제 실행) ② Home 우상단 프로필 → My Scoors ③ World 점수 우선 카드.
//  이 클래스는 현지화 증빙을 위해 앱 언어를 ko로 강제(스킴 en 고정을 오버라이드).
//

import XCTest

final class ScoorQAReworkUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uitests-reset", "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
    }

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

    private func reachMain(username: String) {
        let apple = app.buttons["Continue with Apple"]
        if apple.waitForExistence(timeout: 8) {
            apple.tap()
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 8) {
                field.tap(); field.typeText(username)
                let claim = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Claim'")).firstMatch
                if claim.waitForExistence(timeout: 6) {
                    expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: claim)
                    waitForExpectations(timeout: 8)
                    claim.tap()
                }
            }
            sleep(1)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            tapIfExists(app.buttons["Next"], 6)
            tapIfExists(app.buttons["Try your first Scoor"], 6)
            // "Skip"은 현지화되어 ko에선 "건너뛰기" — 둘 다 시도.
            if !tapIfExists(app.buttons["Skip"], 6) {
                tapIfExists(app.buttons["건너뛰기"], 6)
            }
        }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Main tab bar never appeared")
    }

    func testHomeLocalizedProfileMyScoorsAndWorld() {
        app.launch()
        reachMain(username: "qarework")
        sleep(2)
        snap("QA-01 · Home fully localized (ko)")

        // ② Home 우상단 프로필 아이콘 → My Scoors (My Page 아님).
        let profile = app.buttons["home-profile-button"]
        XCTAssertTrue(profile.waitForExistence(timeout: 6), "Home profile button missing")
        profile.tap()
        sleep(2)
        snap("QA-02 · My Scoors opened from Home profile icon")
        if app.buttons["닫기"].exists { app.buttons["닫기"].tap() }

        // ③ World 점수 우선 카드.
        if tapIfExists(app.buttons["World"], 8) {
            sleep(2)
            snap("QA-03 · World score-first cards")
        }
    }
}
