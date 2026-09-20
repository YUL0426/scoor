import Foundation

/// Editorial translations supplied by the server, separate from user comments.
struct TopicTranslation: Codable, Equatable {
    let title: String
    let subtitle: String?
    let lowLabel: String
    let highLabel: String

    enum CodingKeys: String, CodingKey {
        case title, subtitle
        case lowLabel = "score_low_label", highLabel = "score_high_label"
    }

    static var appLanguage: String { Bundle.main.preferredLocalizations.first ?? "en" }

    static func languageKey(_ language: String) -> String {
        let normalized = language.replacingOccurrences(of: "_", with: "-").lowercased()
        let base = normalized.split(separator: "-").first.map(String.init) ?? "en"
        if base == "pt" { return "pt-BR" }
        if base == "zh" { return "zh-Hans" }
        return ["ko", "en", "ja", "de", "fr", "es"].contains(base) ? base : "en"
    }

    static func resolve(_ translations: [String: TopicTranslation]?, language: String) -> TopicTranslation? {
        let key = languageKey(language)
        // The canonical operational copy is Korean; legacy/community rows can omit translations.
        if key == "ko" { return nil }
        let candidate = translations?[key] ?? translations?["en"]
        guard let candidate, !candidate.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return candidate
    }
}
