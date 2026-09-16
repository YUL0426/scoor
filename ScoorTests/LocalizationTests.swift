import XCTest
@testable import Scoor

@MainActor
final class LocalizationTests: XCTestCase {
    func testTranslatedDocumentsAreBoundToTheCurrentOriginals() throws {
        let translations = try XCTUnwrap(LegalPolicy.translations)
        XCTAssertEqual(translations.version, LegalPolicy.version)
        XCTAssertEqual(translations.sourceSHA256, LegalPolicy.digest)
        for language in ["ja", "fr", "pt-BR"] {
            let terms = try XCTUnwrap(translations.terms[language])
            let privacy = try XCTUnwrap(translations.privacy[language])
            XCTAssertEqual(terms.sections.count, LegalPolicy.package?.terms["en"]?.sections.count)
            XCTAssertEqual(privacy.sections.count, LegalPolicy.package?.privacy["en"]?.sections.count)
            for section in terms.sections + privacy.sections {
                XCTAssertFalse(section.title.isEmpty)
                XCTAssertFalse(section.body.isEmpty)
            }
        }
    }
    func testAllThreeBundlesContainEntryAndPrivacyPermissionCopy() throws {
        for (language, expected) in [("ja", "今日の一日は何点？"), ("fr", "Quelle note pour votre journée ?"), ("pt-BR", "Que nota você dá para o seu dia?")] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: language, ofType: "lproj"))
            let bundle = try XCTUnwrap(Bundle(path: path))
            XCTAssertEqual(bundle.localizedString(forKey: "오늘 점수는 몇 점인가요?", value: nil, table: nil), expected)
            let permission = bundle.localizedString(forKey: "NSPhotoLibraryAddUsageDescription", value: nil, table: "InfoPlist")
            XCTAssertNotEqual(permission, "NSPhotoLibraryAddUsageDescription")
        }
    }
}
