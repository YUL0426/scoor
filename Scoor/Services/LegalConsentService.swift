import Combine
import CryptoKit
import Foundation

struct LegalDocument: Decodable {
    struct Section: Decodable { let title: String; let body: String }
    let title: String
    let sections: [Section]
}

enum LegalPolicy {
    static let version = "2026-09-16.1"
    struct Package: Decodable {
        let version: String
        let terms: [String: LegalDocument]
        let privacy: [String: LegalDocument]
        let sourceSHA256: String?
    }
    static let data: Data? = {
        guard let url = Bundle.main.url(forResource: "legal-policy", withExtension: "json") else { return nil }
        return try? Data(contentsOf: url)
    }()
    static let package: Package? = data.flatMap { try? JSONDecoder().decode(Package.self, from: $0) }
    static let translations: Package? = {
        guard let url = Bundle.main.url(forResource: "legal-policy-translations", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Package.self, from: data)
    }()
    static var isAvailable: Bool {
        guard package?.version == version else { return false }
        if ["ja", "fr", "pt-BR"].contains(language) {
            return translations?.version == version && translations?.sourceSHA256 == digest
                && translations?.terms[language] != nil && translations?.privacy[language] != nil
        }
        return true
    }
    static var digest: String { data.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "" }
    // Use the app's resolved localization, including an iOS per-app language override.
    static var language: String {
        let resolved = Bundle.main.preferredLocalizations.first ?? "en"
        return ["ko", "ja", "fr", "pt-BR"].contains(resolved) ? resolved : "en"
    }
    static func text(_ korean: String, _ english: String) -> String {
        if language == "ko" { return korean }
        return Bundle.main.localizedString(forKey: korean, value: english, table: nil)
    }
    static func document(_ kind: String) -> LegalDocument? {
        guard isAvailable else { return nil }
        let originals = kind == "terms" ? package?.terms : package?.privacy
        let localized = kind == "terms" ? translations?.terms : translations?.privacy
        return localized?[language] ?? originals?[language] ?? originals?["en"]
    }
}

/// The visible action that accepted the terms and asserted signup eligibility.
/// This is not consent to optional, sensitive, or marketing data processing.
enum AccountEntryAction: String, Encodable {
    case apple, google, email
    case continueUsing = "continue"
}

/// Account terms are recorded only after an explicit entry action and successful
/// authentication. The pending receipt is bound to that account, including retries.
@MainActor
final class LegalConsentService: ObservableObject {
    @Published private(set) var readyUserID: UUID?
    @Published private(set) var isChecking = false
    @Published private(set) var errorMessage: String?
    private let client: SupabaseHTTPClient?
    private let defaults: UserDefaults
    private var pendingEntry: (userID: UUID, requestID: UUID, action: AccountEntryAction)?
    private var generation = 0
    private var resolvedIdentity: UUID?
    @Published private(set) var isWithdrawing = false

    func allowsWrites(_ userID: UUID) -> Bool { permits(userID) && !isWithdrawing }
    private var active: (userID: UUID, task: Task<Void, Error>)?

    init(client: SupabaseHTTPClient? = nil, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    func permits(_ userID: UUID?) -> Bool {
        guard let userID else { return false }
        return readyUserID == userID
    }

    func resetForSignOut() {
        generation += 1
        active?.task.cancel(); active = nil
        readyUserID = nil; pendingEntry = nil
        errorMessage = nil; isChecking = false
        resolvedIdentity = nil
    }

    func acceptTerms(action: AccountEntryAction, userID: UUID) async throws {
        guard LegalPolicy.isAvailable else { throw ConsentError.incomplete }
        if let resolvedIdentity, resolvedIdentity != userID { resetForSignOut() }
        // Let the initial read finish before attaching a receipt to a new request.
        // Otherwise acceptTerms() can join a read-only task and lose the entry action.
        if let active { try? await active.task.value }
        if let resolvedIdentity, resolvedIdentity != userID { throw ConsentError.incomplete }
        errorMessage = nil
        if pendingEntry == nil { pendingEntry = (userID, UUID(), action) }
        // An existing ready account may explicitly accept a newer notice at login.
        readyUserID = nil
        do {
            try await resolve(userID: userID)
            guard permits(userID) else { throw ConsentError.incomplete }
        } catch {
            errorMessage = ConsentError.saveFailed.errorDescription
            throw ConsentError.saveFailed
        }
    }

    /// Safe to call from the root view and immediately after authentication.
    func resolve(userID: UUID) async throws {
        if let resolvedIdentity, resolvedIdentity != userID { resetForSignOut() }
        resolvedIdentity = userID
        if readyUserID == userID { return }
        if let active, active.userID == userID { return try await active.task.value }
        active?.task.cancel()
        generation += 1
        let currentGeneration = generation
        readyUserID = nil; isChecking = true; errorMessage = nil
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                if self.generation == currentGeneration { self.isChecking = false; self.active = nil }
            }
            do {
                var accepted = false
                if let client = self.client {
                    if let entry = self.pendingEntry, entry.userID == userID {
                        let body = ConsentRequest(p_version: LegalPolicy.version, p_digest: LegalPolicy.digest,
                                                  p_request_id: entry.requestID, p_language: LegalPolicy.language,
                                                  p_action: entry.action)
                        try await client.send(SupabaseRequest(method: .post, path: "rpc/accept_account_terms",
                                                              body: try SupabaseHTTPClient.encoder.encode(body)))
                    }
                    accepted = try await client.send(SupabaseRequest(method: .post, path: "rpc/has_required_consent",
                                                                    body: Data("{}".utf8)), as: Bool.self)
                } else {
                    let key = self.localKey(userID)
                    if let entry = self.pendingEntry, entry.userID == userID {
                        self.defaults.set(["version": LegalPolicy.version, "digest": LegalPolicy.digest,
                                           "action": entry.action.rawValue,
                                           "acceptedAt": ISO8601DateFormatter().string(from: Date())], forKey: key)
                    }
                    accepted = self.defaults.dictionary(forKey: key)?["digest"] as? String == LegalPolicy.digest
                }
                try Task.checkCancellation()
                guard self.generation == currentGeneration else { return }
                if accepted {
                    self.readyUserID = userID
                    self.pendingEntry = nil
                }
            } catch {
                throw error
            }
        }
        active = (userID, task)
        try await task.value
    }

    func requireAccepted(userID: UUID) async throws {
        try await resolve(userID: userID)
        guard permits(userID) else { throw ConsentError.incomplete }
    }

    func withdraw(userID: UUID) async throws {
        // Keep the management sheet mounted so a failed request can be retried.
        // Suspend the local sync queue while the server processes withdrawal.
        guard !isWithdrawing else { return }
        isWithdrawing = true
        defer { isWithdrawing = false }
        generation += 1
        active?.task.cancel(); active = nil
        pendingEntry = nil
        if let client {
            let body = ["p_request_id": UUID().uuidString]
            try await client.send(SupabaseRequest(method: .post, path: "rpc/withdraw_required_consent",
                                                  body: try SupabaseHTTPClient.encoder.encode(body)))
        }
        defaults.removeObject(forKey: localKey(userID))
        resetForSignOut()
    }


    func withdrawSensitiveTopics() async throws {
        guard let client else { return }
        let body = SensitiveConsentRequest(p_accepted: false, p_version: "2026-09-15.1", p_request_id: UUID())
        try await client.send(SupabaseRequest(method: .post, path: "rpc/set_sensitive_consent", body: try SupabaseHTTPClient.encoder.encode(body)))
    }

    private func localKey(_ userID: UUID) -> String { "scoor.legal.\(userID.uuidString).\(LegalPolicy.version)" }
    private struct ConsentRequest: Encodable {
        let p_version: String; let p_digest: String; let p_request_id: UUID; let p_language: String
        let p_action: AccountEntryAction
    }
    enum ConsentError: LocalizedError {
        case incomplete, saveFailed
        var errorDescription: String? {
            if self == .saveFailed {
                return LegalPolicy.text("로그인은 완료됐지만 가입을 마무리하지 못했어요. 다시 시도해 주세요.", "You’re signed in, but we couldn’t finish setup. Please try again.")
            }
            return LegalPolicy.text("이용 안내를 확인하고 계속해 주세요.", "Please review the notice and continue.")
        }
    }
}
