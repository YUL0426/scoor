//
//  ScoorPolishScreenshotsUITests.swift
//  ScoorUITests
//
//  Pre-launch polish 스프린트 산출물용 스크린샷 + 스모크 검증.
//  캡처: ① 점수 입력(인라인 사유 + 100→로고) ② 피드(점수 우선) ③ My Page(My Scoors).
//  언어는 스킴 TestAction에서 en 고정(현지화 도입 후 테스트 헤르메틱).
//

import XCTest

final class ScoorPolishScreenshotsUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uitests-reset"]
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
            tapIfExists(app.buttons["Next"], 8)
            tapIfExists(app.buttons["Try your first Scoor"], 8)
            tapIfExists(app.buttons["Skip"], 8)
        }
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Main tab bar never appeared")
    }

    private func clearKeypad(_ count: Int) {
        let back = app.buttons["delete.left"]
        for _ in 0..<count where back.exists { back.tap() }
    }

    private func typeDigits(_ digits: String) {
        for d in digits.map({ String($0) }) {
            let key = app.buttons[d]
            if key.waitForExistence(timeout: 4) { key.tap() }
        }
    }

    func testCaptureKeyScreens() {
        app.launch()
        reachMain(username: "polishqa")
        snap("P-00 · Home")

        // ① 점수 입력 — 100 입력 시 숫자 대신 Scoor 로고, 인라인 사유 입력.
        app.buttons["Add today's score"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad missing")
        sleep(1)
        clearKeypad(3)
        typeDigits("100")
        snap("P-01 · Score input · 100 shows Scoor logo (not numeral)")

        let reason = app.textFields["reason-field"]
        if reason.waitForExistence(timeout: 4) {
            reason.tap()
            reason.typeText("Best day in a while")
            snap("P-02 · Inline reason (no modal, no tags)")
            if app.keyboards.buttons["Done"].exists { app.keyboards.buttons["Done"].tap() }
        }
        // Save and return.
        for label in ["업데이트", "Scoor!"] where app.buttons[label].exists { app.buttons[label].tap(); break }
        _ = app.buttons["Home"].waitForExistence(timeout: 8)

        // ② 피드 — 점수 우선(우측 큰 점수).
        if tapIfExists(app.buttons["Feed"], 8) {
            sleep(2)
            snap("P-03 · Feed · score-first (large right-anchored)")
        }

        // ③ My Page — My Scoors 섹션.
        if tapIfExists(app.buttons["My Page"], 8) {
            sleep(2)
            snap("P-04 · My Page · My Scoors history")
        }
    }
}
