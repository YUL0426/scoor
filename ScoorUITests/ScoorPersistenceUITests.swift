//
//  ScoorPersistenceUITests.swift
//  ScoorUITests
//
//  End-to-end UI QA for Sprint 0 score persistence + Phase-1 regression.
//  Drives the real UI (onboarding → create → restart → verify) and captures
//  screenshots as keepAlways attachments for the QA report.
//

import XCTest

final class ScoorPersistenceUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        // Start each test from a brand-new-install slate (no leftover scores /
        // onboarding from prior runs on this simulator). Mid-test relaunches that
        // verify persistence drop this arg so saved data survives the restart.
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
        if el.waitForExistence(timeout: timeout) {
            el.tap(); return true
        }
        return false
    }

    private func centerTap() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // Drives splash → welcome → nickname → complete → tour → (skip first scoor) → Main.
    // Adaptive: if the app already resumed past onboarding (persisted stage), it
    // simply confirms Main and returns — so the test is robust to prior state.
    private func reachMain(username: String) {
        let apple = app.buttons["Continue with Apple"]
        if apple.waitForExistence(timeout: 8) {
            snap("01 · Signup Welcome")
            apple.tap()

            // Nickname
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 8) {
                field.tap()
                field.typeText(username)
                if app.staticTexts["Choose your Scoor name"].exists {
                    app.staticTexts["Choose your Scoor name"].tap() // dismiss keyboard
                }
                let claim = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Claim'")).firstMatch
                if claim.waitForExistence(timeout: 6) {
                    let enabled = NSPredicate(format: "isEnabled == true")
                    expectation(for: enabled, evaluatedWith: claim)
                    waitForExpectations(timeout: 8)
                    snap("02 · Nickname (available)")
                    claim.tap()
                }
            }

            // Complete (auto-advances ~2.8s; tap to hasten)
            sleep(1); centerTap()
            snap("03 · Signup Complete / Tour")

            // Tour page 1 → 2 → first scoor
            tapIfExists(app.buttons["Next"], 8)
            tapIfExists(app.buttons["Try your first Scoor"], 8)

            // First Scoor prompt — skip to land on Main with NO score
            snap("04 · First Scoor prompt")
            tapIfExists(app.buttons["Skip"], 8)
        }

        // Main / Home
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Main tab bar never appeared")
        XCTAssertTrue(app.buttons["Add today's score"].waitForExistence(timeout: 6), "FAB missing on Home")
    }

    // Enters digits on the score sheet keypad and submits.
    private func enterScoreViaFAB(_ digits: String, doneLabels: [String]) {
        app.buttons["Add today's score"].tap()
        // keypad sheet
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad did not appear")
        for d in digits.map({ String($0) }) {
            let key = app.buttons[d]
            XCTAssertTrue(key.waitForExistence(timeout: 4), "Keypad digit \(d) missing")
            key.tap()
        }
        snap("Keypad · entered \(digits)")
        // tap whichever done label is present (Scoor! for create, 업데이트 for update)
        var tapped = false
        for label in doneLabels where app.buttons[label].exists {
            app.buttons[label].tap(); tapped = true; break
        }
        XCTAssertTrue(tapped, "Done/submit button \(doneLabels) not found")
        // sheet auto-dismisses after save
        _ = app.buttons["Add today's score"].waitForExistence(timeout: 8)
    }

    private func clearKeypad(_ count: Int) {
        let back = app.buttons["delete.left"]
        for _ in 0..<count where back.exists { back.tap() }
    }

    // MARK: - The end-to-end test

    func testEndToEndPersistenceAndRegression() {
        app.launch()

        // ===== Scenario 1: Create Scoor =====
        reachMain(username: "scoorqa")
        snap("05 · Home (no score yet)")

        enterScoreViaFAB("73", doneLabels: ["Scoor!", "업데이트"])
        XCTAssertTrue(app.staticTexts["73"].waitForExistence(timeout: 8),
                      "Home should display the created score 73")
        snap("04 · Home after creating 73")

        // Calendar (My Page) + Stats before restart
        app.buttons["My Page"].tap()
        sleep(1)
        snap("05 · My Page / Calendar after create")
        // try to open detailed stats if a control exists
        for label in ["통계", "통계 보기", "Stats", "See stats", "전체 통계"] where app.buttons[label].exists {
            app.buttons[label].tap(); sleep(1); snap("06 · Stats detail"); break
        }

        // ===== Force close + reopen =====
        app.terminate()
        app.launchArguments = [] // relaunch WITHOUT reset so persisted data survives
        app.launch()
        // resumes straight to Main
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12),
                      "After relaunch app should resume on Main")
        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["73"].waitForExistence(timeout: 8),
                      "PERSISTENCE FAIL: score 73 gone after restart")
        snap("07 · Home after RESTART (score persisted)")
        app.buttons["My Page"].tap(); sleep(1)
        snap("08 · Calendar after RESTART")

        // ===== Scenario 2: Edit Scoor =====
        app.buttons["Home"].tap()
        app.buttons["Add today's score"].tap()
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad (edit) did not appear")
        // In update mode the keypad is prefilled with the current value (73); clear it.
        clearKeypad(3)
        app.buttons["9"].tap()
        app.buttons["1"].tap()
        snap("09 · Edit input 91")
        var savedEdit = false
        for label in ["업데이트", "Scoor!"] where app.buttons[label].exists {
            app.buttons[label].tap(); savedEdit = true; break
        }
        XCTAssertTrue(savedEdit, "Update button not found")
        _ = app.buttons["Add today's score"].waitForExistence(timeout: 8)
        XCTAssertTrue(app.staticTexts["91"].waitForExistence(timeout: 8), "Home should show edited 91")
        snap("10 · Home after edit 91")

        // Restart and verify the EDIT persisted
        app.terminate()
        app.launchArguments = [] // relaunch WITHOUT reset so persisted data survives
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Relaunch failed (edit)")
        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["91"].waitForExistence(timeout: 8),
                      "PERSISTENCE FAIL: edited score 91 gone after restart")
        XCTAssertFalse(app.staticTexts["73"].exists, "Old value 73 should be gone after edit")
        snap("11 · Home after RESTART (edit persisted)")

        // ===== Scenario 3: Multiple-day records (probe the UI capability) =====
        app.buttons["My Page"].tap(); sleep(1)
        // Probe: can a PAST empty calendar cell create a record? Tap a low day number.
        for day in ["1", "2", "3", "5"] where app.staticTexts[day].exists {
            app.staticTexts[day].tap(); break
        }
        sleep(1)
        snap("12 · Calendar past-cell tap (multi-day capability probe)")
        // dismiss any sheet
        if app.buttons["닫기"].exists { app.buttons["닫기"].tap() }
        else { centerTap() }

        // ===== Scenario 4: Regression — every tab loads, no crash =====
        app.buttons["Home"].tap();   sleep(1); snap("13 · Regression Home")
        app.buttons["Feed"].tap();   sleep(1); snap("14 · Regression Feed")
        app.buttons["World"].tap();  sleep(1); snap("15 · Regression World")
        app.buttons["My Page"].tap();sleep(1); snap("16 · Regression My Page / Profile")
        // App still alive == no crash
        XCTAssertEqual(app.state, .runningForeground, "App should still be running (no crash)")
    }
}
