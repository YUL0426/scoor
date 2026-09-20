import XCTest
@testable import Scoor

@MainActor
final class LocalizationTests: XCTestCase {
    func testCompiledEnglishBundleContainsNoKoreanUIValues() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "en", ofType: "lproj"))
        let url = URL(fileURLWithPath: path).appendingPathComponent("Localizable.strings")
        let strings = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        XCTAssertGreaterThan(strings.count, 300)
        for (key, value) in strings {
            XCTAssertNil(value.range(of: "[가-힣]", options: .regularExpression), "English bundle contains Korean: \(key) → \(value)")
        }
        let bundle = try XCTUnwrap(Bundle(path: path))
        for (key, expected) in [("오늘 기록하기", "Record today"), ("완료", "Done"),
                                ("계정 삭제", "Delete account"), ("부정적", "Negative"),
                                ("나의 하루 흐름", "My daily rhythm")] {
            XCTAssertEqual(bundle.localizedString(forKey: key, value: nil, table: nil), expected)
        }
    }

    func testCustomTopicScoreMeaningsArePreserved() {
        XCTAssertEqual(WorldTopic.localizedScoreMeaning("새로운 사용자 기준"), "새로운 사용자 기준")
        XCTAssertEqual(WorldTopic.localizedScoreMeaning("부정적"), String(localized: "부정적"))
        XCTAssertEqual(WorldTopic.localizedScoreMeaning("찬성"), String(localized: "찬성"))
    }

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
