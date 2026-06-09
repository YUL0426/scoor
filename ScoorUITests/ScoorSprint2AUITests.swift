//
//  ScoorSprint2AUITests.swift
//  ScoorUITests
//
//  End-to-end UI QA for Sprint 2-A (REVISED) — Emotion as a DERIVED field.
//
//  The product vision reverted: the daily Scoor input is score + reason ONLY.
//  Mood is no longer user-selected; it is left for future automatic analysis.
//  These tests verify:
//   1. The score sheet exposes NO emotion selector — only score + reason.
//   2. A record saved with score+reason persists across a restart and shows
//      NO derived mood pill (mood fields remain dormant / nil until analysis).
//

import XCTest

final class ScoorSprint2AUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        // Fresh-install slate per test; persistence relaunches drop this arg.
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
        XCTAssertTrue(app.buttons["Add today's score"].waitForExistence(timeout: 6), "FAB missing on Home")
    }

    private func clearKeypad(_ count: Int) {
        let back = app.buttons["delete.left"]
        for _ in 0..<count where back.exists { back.tap() }
    }

    private func typeDigits(_ digits: String) {
        for d in digits.map({ String($0) }) {
            let key = app.buttons[d]
            XCTAssertTrue(key.waitForExistence(timeout: 4), "Keypad digit \(d) missing")
            key.tap()
        }
    }

    private func submit() {
        for label in ["업데이트", "Scoor!"] where app.buttons[label].exists {
            app.buttons[label].tap(); return
        }
        XCTFail("Submit button not found")
    }

    private func openMyPage() { app.buttons["My Page"].tap(); sleep(1) }

    // MARK: - 1. Input is score + reason only (NO emotion selector)

    func test1NoEmotionSelectorScoreAndReasonOnly() {
        app.launch()
        reachMain(username: "scoorqa")

        app.buttons["Add today's score"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad did not appear")

        // The emotion selector chips must be GONE.
        XCTAssertFalse(app.buttons["mood-chip-happy"].waitForExistence(timeout: 2),
                       "REGRESSION: emotion selector chip still present in score input")
        XCTAssertFalse(app.buttons["mood-chip-calm"].exists,
                       "REGRESSION: emotion selector chip still present in score input")
        // The two intended inputs remain: keypad (score) + reason pill.
        XCTAssertTrue(app.buttons["reason-pill"].exists, "Reason pill missing")
        snap("S2Arev-01 · Score sheet: score + reason only (no emotion selector)")

        sleep(1)
        clearKeypad(3)
        typeDigits("70")

        // Reason (free text) — the only other input.
        app.buttons["reason-pill"].tap()
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 6), "Reason editor missing")
        editor.tap()
        editor.typeText("QA reason text")
        snap("S2Arev-02 · Reason entered")
        app.buttons["저장하기"].tap()

        // BUG-011: completing the reason text auto-saves the whole entry — no
        // separate "Scoor!" tap. The sheet dismisses and Home reflects the score.
        _ = app.buttons["Add today's score"].waitForExistence(timeout: 8)
        XCTAssertTrue(app.staticTexts["70"].waitForExistence(timeout: 8), "Home should show 70")
        snap("S2Arev-03 · Home after score + reason (auto-saved)")
    }

    // MARK: - 2. Score+reason record persists; no derived mood shown

    func test2RecordPersistsWithNoDerivedMood() {
        app.launch()
        reachMain(username: "scoorqa")

        app.buttons["Add today's score"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad did not appear")
        sleep(1)
        clearKeypad(3)
        typeDigits("88")
        submit()
        _ = app.buttons["Add today's score"].waitForExistence(timeout: 8)
        XCTAssertTrue(app.staticTexts["88"].waitForExistence(timeout: 8), "Home should show 88")

        // Restart → value persists (Sprint 0 behavior intact).
        app.terminate()
        app.launchArguments = [] // relaunch WITHOUT reset so persisted data survives
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Relaunch failed")
        XCTAssertTrue(app.staticTexts["88"].waitForExistence(timeout: 8),
                      "PERSISTENCE FAIL: 88 gone after restart")

        // Open today's detail — there must be NO derived mood pill (fields dormant).
        openMyPage()
        let today = Calendar.current.component(.day, from: Date())
        let cell = app.buttons["calendar-day-\(today)"]
        XCTAssertTrue(cell.waitForExistence(timeout: 8), "Today cell missing")
        cell.tap()
        XCTAssertTrue(app.staticTexts["88"].waitForExistence(timeout: 6), "Detail should show 88")
        let moodPill = app.descendants(matching: .any).matching(identifier: "detail-mood").firstMatch
        XCTAssertFalse(moodPill.waitForExistence(timeout: 2),
                       "Unexpected derived mood pill — mood should stay dormant until analysis")
        snap("S2Arev-04 · Day detail: no derived mood (score + reason only)")
        if app.buttons["닫기"].exists { app.buttons["닫기"].tap() }
    }
}
