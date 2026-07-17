//
//  ScoorSprint1UITests.swift
//  ScoorUITests
//
//  End-to-end UI QA for Sprint 1:
//   1. Home recent-day card → edit flow
//   2. Delete score flow from the calendar day-detail sheet
//   3. Bio update persistence (across an app restart)
//
//  Drives the real UI and captures screenshots as keepAlways attachments for
//  the QA report. Helpers mirror ScoorPersistenceUITests so the suite stays
//  robust to whatever onboarding / persisted state the app resumes from.
//

import XCTest

final class ScoorSprint1UITests: XCTestCase {

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
        if el.waitForExistence(timeout: timeout) {
            el.tap(); return true
        }
        return false
    }

    private func centerTap() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// Swipe up on the Home scroll view until a button matching `predicate` is
    /// hittable (or we give up after `maxSwipes`). Returns the element.
    @discardableResult
    private func scrollToButton(_ predicate: NSPredicate, maxSwipes: Int = 6) -> XCUIElement {
        let el = app.buttons.matching(predicate).firstMatch
        var swipes = 0
        while !(el.exists && el.isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
        return el
    }

    // Drives splash → welcome → nickname → complete → tour → (skip first scoor) → Main.
    // Adaptive: if the app already resumed past onboarding, it just confirms Main.
    private func reachMain(username: String) {
        let apple = app.buttons["Continue with Apple"]
        if apple.waitForExistence(timeout: 8) {
            apple.tap()

            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 8) {
                field.tap()
                field.typeText(username)
                if app.staticTexts["Choose your Scoor name"].exists {
                    app.staticTexts["Choose your Scoor name"].tap()
                }
                let claim = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Claim'")).firstMatch
                if claim.waitForExistence(timeout: 6) {
                    let enabled = NSPredicate(format: "isEnabled == true")
                    expectation(for: enabled, evaluatedWith: claim)
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

    /// Enter digits on the score keypad and submit with whichever done label is shown.
    private func enterDigitsAndSubmit(_ digits: String, clearFirst: Int = 0) {
        XCTAssertTrue(app.buttons["1"].waitForExistence(timeout: 6), "Keypad did not appear")
        // Allow async load of an existing value to settle before clearing.
        sleep(1)
        let back = app.buttons["delete.left"]
        for _ in 0..<clearFirst where back.exists { back.tap() }
        for d in digits.map({ String($0) }) {
            let key = app.buttons[d]
            XCTAssertTrue(key.waitForExistence(timeout: 4), "Keypad digit \(d) missing")
            key.tap()
        }
        var tapped = false
        for label in ["업데이트", "Scoor!"] where app.buttons[label].exists {
            app.buttons[label].tap(); tapped = true; break
        }
        XCTAssertTrue(tapped, "Submit button (업데이트 / Scoor!) not found")
    }

    private func openMyPage() {
        app.buttons["My Page"].tap()
        sleep(1)
    }

    // MARK: - 1. Home recent-day card → edit flow

    func test1RecentCardEditFlow() {
        app.launch()
        reachMain(username: "scoorqa")

        // Create a PAST-day entry via the calendar so it appears in Home's recent list
        // (the recent list excludes today). Day 1 of the current month is always past
        // unless today IS the 1st — fall back to day 2 in that case.
        openMyPage()
        let today = Calendar.current.component(.day, from: Date())
        let pastDay = today > 1 ? 1 : 2
        let pastCell = app.buttons["calendar-day-\(pastDay)"]
        XCTAssertTrue(pastCell.waitForExistence(timeout: 8), "Calendar day-\(pastDay) cell missing")
        pastCell.tap()
        snap("S1-01 · Past-day input sheet")
        enterDigitsAndSubmit("50")
        _ = app.buttons["My Page"].waitForExistence(timeout: 8)
        snap("S1-02 · Calendar after creating past day = 50")

        // Go Home, find the recent card showing 50, tap it to edit.
        app.buttons["Home"].tap()
        sleep(1)
        let card50 = scrollToButton(NSPredicate(format: "label CONTAINS 'score 50'"))
        XCTAssertTrue(card50.exists, "Recent card for score 50 never appeared on Home")
        snap("S1-03 · Home recent list (50)")
        card50.tap()

        // Edit sheet opens prefilled in update mode → change 50 → 62.
        snap("S1-04 · Edit sheet opened from recent card")
        enterDigitsAndSubmit("62", clearFirst: 3)
        _ = app.buttons["Home"].waitForExistence(timeout: 8)

        // Verify the edit took: a 62 recent card now exists, the 50 one is gone.
        let card62 = scrollToButton(NSPredicate(format: "label CONTAINS 'score 62'"))
        XCTAssertTrue(card62.waitForExistence(timeout: 8), "EDIT FAIL: recent card not updated to 62")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS 'score 50'")).firstMatch.exists,
                       "EDIT FAIL: stale 50 card still present after edit")
        snap("S1-05 · Home recent list after edit (62)")
    }

    // MARK: - 2. Delete score flow from calendar detail

    func test2CalendarDeleteFlow() {
        app.launch()
        reachMain(username: "scoorqa")

        // Create today's score = 80 via the FAB.
        app.buttons["Add today's score"].tap()
        enterDigitsAndSubmit("80", clearFirst: 3)
        _ = app.buttons["Add today's score"].waitForExistence(timeout: 8)
        XCTAssertTrue(app.staticTexts["80"].waitForExistence(timeout: 8), "Home should show today's 80")
        snap("S2-01 · Home with today = 80")

        // Open today's calendar cell → detail sheet.
        openMyPage()
        let today = Calendar.current.component(.day, from: Date())
        let todayCell = app.buttons["calendar-day-\(today)"]
        XCTAssertTrue(todayCell.waitForExistence(timeout: 8), "Today's calendar cell missing")
        todayCell.tap()

        let deleteBtn = app.buttons["delete-score-button"]
        XCTAssertTrue(deleteBtn.waitForExistence(timeout: 6), "Detail sheet delete button missing")
        snap("S2-02 · Calendar day detail (delete available)")
        deleteBtn.tap()

        // Confirmation dialog → 삭제.
        let confirm = app.buttons["삭제"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 6), "Delete confirmation not shown")
        snap("S2-03 · Delete confirmation dialog")
        confirm.tap()
        sleep(1)
        snap("S2-04 · Calendar after delete")

        // Verify deletion: re-tapping today's cell now opens CREATE mode (Scoor!),
        // not the detail/update sheet (업데이트).
        let todayCell2 = app.buttons["calendar-day-\(today)"]
        XCTAssertTrue(todayCell2.waitForExistence(timeout: 6), "Today's cell missing after delete")
        todayCell2.tap()
        XCTAssertTrue(app.buttons["Scoor!"].waitForExistence(timeout: 6),
                      "DELETE FAIL: expected create-mode keypad (Scoor!) after deletion")
        XCTAssertFalse(app.buttons["업데이트"].exists,
                       "DELETE FAIL: update-mode button present — entry was not deleted")
        snap("S2-05 · Re-tap shows empty create keypad (deleted)")
        // Close keypad without saving.
        if app.buttons["닫기"].exists { app.buttons["닫기"].tap() }
    }

    // MARK: - 3. Bio persistence

    func test3BioPersistence() {
        app.launch()
        reachMain(username: "scoorqa")

        let bioText = "QA bio persists 1234"

        openMyPage()
        let editProfile = app.buttons["edit-profile-button"]
        XCTAssertTrue(editProfile.waitForExistence(timeout: 8), "Edit-profile button missing")
        editProfile.tap()

        let bioField = app.textFields["profile-bio-field"]
        XCTAssertTrue(bioField.waitForExistence(timeout: 6), "Bio field missing")
        bioField.tap()
        // Clear anything already there, then type.
        if let existing = bioField.value as? String, !existing.isEmpty,
           existing != "나를 한 줄로 표현해보세요" {
            bioField.clearText()
        }
        bioField.typeText(bioText)
        snap("S3-01 · Bio entered in profile edit")
        app.buttons["저장"].tap()
        sleep(1)

        // Bio now shown on the profile header.
        let bioLabel = app.staticTexts["profile-bio-text"]
        XCTAssertTrue(bioLabel.waitForExistence(timeout: 6), "Bio not surfaced on profile after save")
        XCTAssertTrue(bioLabel.label.contains("QA bio persists"), "Saved bio text mismatch: \(bioLabel.label)")
        snap("S3-02 · Profile header shows saved bio")

        // Restart and confirm the bio persisted.
        app.terminate()
        app.launchArguments = [] // relaunch WITHOUT reset so the saved bio survives
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "Relaunch failed (bio)")
        openMyPage()
        let bioLabel2 = app.staticTexts["profile-bio-text"]
        XCTAssertTrue(bioLabel2.waitForExistence(timeout: 8),
                      "PERSISTENCE FAIL: bio gone after restart")
        XCTAssertTrue(bioLabel2.label.contains("QA bio persists"),
                      "PERSISTENCE FAIL: bio text wrong after restart: \(bioLabel2.label)")
        snap("S3-03 · Profile bio persisted after RESTART")
    }
}

// MARK: - Text field helper

private extension XCUIElement {
    /// Clear a text field by selecting all and deleting.
    func clearText() {
        guard let value = self.value as? String, !value.isEmpty else { return }
        let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
        self.typeText(deletes)
    }
}
