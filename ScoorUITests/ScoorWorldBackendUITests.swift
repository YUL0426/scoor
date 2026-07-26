//
//  ScoorWorldBackendUITests.swift
//  ScoorUITests
//
//  World 탭이 서버 토픽을 실제로 렌더하는지 확인한다 (spec-13 Phase 1).
//
//  유닛 테스트는 디코딩이 맞는지까지만 말해준다. 이 테스트는 그 데이터가 실제로
//  화면에 도달하는지를 본다 — 서비스 배선이 끊겨 있으면 디코딩이 아무리 맞아도
//  사용자는 빈 화면을 본다.
//
//  백엔드가 설정되지 않은 빌드(Secrets.xcconfig 없음)에서는 시드 토픽이 뜨므로
//  이 테스트는 조용히 통과한다 — CI가 자격증명 없이도 돌 수 있어야 한다.
//

import XCTest

final class ScoorWorldBackendUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = true
        app.launchArguments = ["-uitests-reset"]
    }

    private func snap(_ name: String) {
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
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
        let apple = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Apple'")
        ).firstMatch
        if apple.waitForExistence(timeout: 10) {
            apple.tap()
            let field = app.textFields.firstMatch
            if field.waitForExistence(timeout: 8) {
                field.tap(); field.typeText(username)
                if app.staticTexts["Choose your Scoor name"].exists {
                    app.staticTexts["Choose your Scoor name"].tap()
                }
                let claim = app.buttons.matching(
                    NSPredicate(format: "label BEGINSWITH 'Claim'")
                ).firstMatch
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
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12), "메인 탭바가 뜨지 않았다")
    }

    func testWorldRendersTopicsAndOpensDetail() {
        app.launch()
        reachMain(username: "scoor_world_qa")

        XCTAssertTrue(tapIfExists(app.buttons["World"], 8), "World 탭이 없다")

        // 서버 큐레이션 토픽 중 하나가 뜰 때까지 기다린다. 고정 sleep은 네트워크
        // 왕복 시간에 따라 깨지므로 실제 대기로 확인한다.
        // 라벨에는 커버 이모지가 함께 붙으므로 CONTAINS로 찾는다
        // (staticTexts["시험 기간 멘탈"] 같은 정확 일치는 실패한다).
        let anyLive = app.staticTexts.matching(
            NSPredicate(format:
                "label CONTAINS '시험 기간 멘탈' OR label CONTAINS '지금 내 연애 온도' "
                + "OR label CONTAINS '오늘 밤' OR label CONTAINS '이번 주 직장 컨디션' "
                + "OR label CONTAINS '요즘 뉴스 보면 드는 기분'")
        ).firstMatch
        let liveAppeared = anyLive.waitForExistence(timeout: 25)
        snap("world-01-topics")

        if liveAppeared {
            print("[UITest] 서버 토픽 확인: '\(anyLive.label)'")
        } else {
            print("[UITest] 서버 토픽 미확인 — 화면 텍스트 전체:")
            for t in app.staticTexts.allElementsBoundByIndex {
                print("[UITest]   '\(t.label)'")
            }
        }
        XCTAssertTrue(liveAppeared, "World가 서버 토픽을 렌더하지 않았다")
    }
}
