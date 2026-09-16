import XCTest

final class ScoorLocalizationUITests: XCTestCase {
    func testJapaneseEntryDocumentsAndMain() { verify(language: "ja", locale: "ja_JP", apple: "Appleで続ける", heading: "今日の一日は何点？", terms: "利用規約", privacy: "プライバシーに関するお知らせ", done: "閉じる", home: "ホーム") }
    func testFrenchEntryDocumentsAndMain() { verify(language: "fr", locale: "fr_FR", apple: "Continuer avec Apple", heading: "Quelle note pour votre journée ?", terms: "Conditions d’utilisation", privacy: "Notice de confidentialité", done: "Fermer", home: "Accueil") }
    func testBrazilianPortugueseEntryDocumentsAndMain() { verify(language: "pt-BR", locale: "pt_BR", apple: "Continuar com a Apple", heading: "Que nota você dá para o seu dia?", terms: "Termos de Uso", privacy: "Aviso de Privacidade", done: "Fechar", home: "Início") }

    func testBrazilianPortugueseLargeTextKeepsActionsReachable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-AppleLanguages", "(pt-BR)", "-AppleLocale", "pt_BR", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let scroll = app.scrollViews["account-entry-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))
        for id in ["signup-apple", "signup-google", "legal-read-terms", "legal-read-privacy"] {
            let button = app.buttons[id]
            for _ in 0..<12 where !button.isHittable { scroll.swipeUp() }
            XCTAssertTrue(button.isHittable, id)
        }
        capture(app, "pt-BR-large-text")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        // A newly hittable element can precede the end of the root's fade transition.
        Thread.sleep(forTimeInterval: 0.8)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func verify(language: String, locale: String, apple: String, heading: String, terms: String, privacy: String, done: String, home: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-uitests-reset", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        let entry = app.buttons["signup-apple"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertEqual(entry.label, apple)
        XCTAssertTrue(app.staticTexts[heading].exists)
        XCTAssertTrue(entry.isHittable)
        XCTAssertTrue(app.buttons["signup-google"].isHittable)
        capture(app, "\(language)-entry")
        for (kind, title) in [("terms", terms), ("privacy", privacy)] {
            let link = app.buttons["legal-read-\(kind)"]
            for _ in 0..<5 where !link.isHittable { app.swipeUp() }
            XCTAssertTrue(link.isHittable)
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
            capture(app, "\(language)-\(kind)")
            app.buttons[done].tap()
        }
        for _ in 0..<5 where !entry.isHittable { app.swipeDown() }
        entry.tap()
        XCTAssertTrue(app.buttons["main-tab-Home"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["main-tab-Home"].label, home)
        capture(app, "\(language)-home")
        app.buttons["main-add-score"].tap()
        XCTAssertTrue(app.buttons["score-back-button"].waitForExistence(timeout: 5))
        capture(app, "\(language)-score")
        app.buttons["score-back-button"].tap()
        app.buttons["main-tab-My Page"].tap()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 5))
        capture(app, "\(language)-profile")
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.buttons["settings-language-button"].waitForExistence(timeout: 5))
        capture(app, "\(language)-settings")
    }
}
