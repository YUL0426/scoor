import XCTest
@testable import Scoor

@MainActor
final class LegalConsentTests: XCTestCase {
    private func local() -> LegalConsentService {
        LegalConsentService(defaults: UserDefaults(suiteName: "legal-test-\(UUID())")!)
    }
    private func remote() -> LegalConsentService {
        let client = SupabaseHTTPClient(config: SupabaseConfig(baseURL: URL(string: "https://consent.invalid")!, anonKey: "test"),
                                        tokenProvider: nil, session: ReleaseAuditURLProtocol.session())
        return LegalConsentService(client: client)
    }
    func testConsentRejectionPreservesQueuedRecords() {
        XCTAssertTrue(APIError.rejected("Required agreements must be accepted before submitting data").isConsentRejection)
        XCTAssertTrue(APIError.rejected("Publication agreement must be accepted before posting").isConsentRejection)
        XCTAssertFalse(APIError.rejected("Invalid score value").isConsentRejection)
    }
    func testBundledDocumentsAreCompleteAndMatchServerVersion() {
        XCTAssertTrue(LegalPolicy.isAvailable)
        XCTAssertEqual(LegalPolicy.digest, "67b17e8f2ed8aabe0fd7b9b44b3b28656879305b3173deb2993a72a35cd6ee11")
        for language in ["ko", "en"] {
            XCTAssertFalse(LegalPolicy.package?.terms[language]?.sections.isEmpty ?? true)
            XCTAssertFalse(LegalPolicy.package?.privacy[language]?.sections.isEmpty ?? true)
        }
    }
    func testOpeningAppOrDocumentsDoesNotAcceptTerms() async throws {
        let service = local(), user = UUID()
        _ = LegalPolicy.document("terms")
        _ = LegalPolicy.document("privacy")
        try await service.resolve(userID: user)
        XCTAssertFalse(service.permits(nil))
        XCTAssertFalse(service.permits(user))
    }
    func testEntryActionIsBoundToOneAuthenticatedAccount() async throws {
        let service = local(), a = UUID(), b = UUID()
        try await service.acceptTerms(action: .apple, userID: a)
        XCTAssertTrue(service.permits(a))
        XCTAssertFalse(service.permits(nil))
        try await service.resolve(userID: b)
        XCTAssertFalse(service.permits(a))
        XCTAssertFalse(service.permits(b))
        try await service.acceptTerms(action: .google, userID: b)
        XCTAssertTrue(service.permits(b))
    }
    func testWithdrawalAndSignoutCloseTheGate() async throws {
        let service = local(), user = UUID()
        try await service.acceptTerms(action: .apple, userID: user)
        try await service.withdraw(userID: user)
        try await service.resolve(userID: user)
        XCTAssertFalse(service.permits(user))
        XCTAssertFalse(service.permits(nil))
        try await service.acceptTerms(action: .apple, userID: user)
        service.resetForSignOut()
        XCTAssertFalse(service.permits(user))
    }
    func testServerFailureDoesNotUnlockAndRetryUsesSameReceiptID() async throws {
        var requests: [String] = []
        var fail = true
        ReleaseAuditURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("accept_account_terms") {
                let json = try JSONSerialization.jsonObject(with: Self.body(of: request)) as! [String: Any]
                requests.append(json["p_request_id"] as! String)
                XCTAssertEqual(json["p_action"] as? String, "apple")
                XCTAssertNil(json["account_data"])
                XCTAssertNil(json["sensitive_consent"])
                return (fail ? 503 : 204, Data())
            }
            return (200, Data("true".utf8))
        }
        let service = remote(), user = UUID()
        do { try await service.acceptTerms(action: .apple, userID: user); XCTFail("Failure passed") } catch {}
        XCTAssertFalse(service.permits(user))
        XCTAssertFalse(service.isChecking)
        fail = false
        try await service.acceptTerms(action: .apple, userID: user)
        XCTAssertTrue(service.permits(user))
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
    }
    func testAReceiptResponseWithoutCurrentConsentDoesNotUnlock() async {
        ReleaseAuditURLProtocol.handler = { request in
            (200, request.url!.path.hasSuffix("has_required_consent") ? Data("false".utf8) : Data())
        }
        let service = remote(), user = UUID()
        do { try await service.acceptTerms(action: .apple, userID: user); XCTFail("Stale receipt unlocked account") } catch {}
        XCTAssertFalse(service.permits(user))
    }
    func testInitialLookupFailureDoesNotShowSaveErrorOrUnlock() async {
        ReleaseAuditURLProtocol.handler = { _ in (503, Data()) }
        let service = remote(), user = UUID()
        do { try await service.resolve(userID: user); XCTFail("Lookup should fail") } catch {}
        XCTAssertNil(service.errorMessage)
        XCTAssertFalse(service.permits(user))
        XCTAssertFalse(service.isChecking)
    }

    func testWithdrawalFailureRemainsRetryable() async throws {
        var failWithdrawal = true
        ReleaseAuditURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("withdraw_required_consent") {
                return (failWithdrawal ? 503 : 204, Data())
            }
            return (200, Data("true".utf8))
        }
        let service = remote(), user = UUID()
        try await service.acceptTerms(action: .apple, userID: user)
        do { try await service.withdraw(userID: user); XCTFail("Failed withdrawal reported success") } catch {}
        XCTAssertTrue(service.permits(user), "Keep account-management UI available for retry")
        XCTAssertFalse(service.isWithdrawing)
        failWithdrawal = false
        try await service.withdraw(userID: user)
        XCTAssertFalse(service.permits(user))
    }
    func testFailedEntryCannotBeAppliedToAnotherAccount() async throws {
        var saves = 0
        ReleaseAuditURLProtocol.handler = { request in
            if request.url!.path.hasSuffix("accept_account_terms") { saves += 1; return (503, Data()) }
            return (200, Data("false".utf8))
        }
        let service = remote(), a = UUID(), b = UUID()
        do { try await service.acceptTerms(action: .google, userID: a); XCTFail("Save should fail") } catch {}
        try await service.resolve(userID: b)
        XCTAssertEqual(saves, 1)
        XCTAssertFalse(service.permits(a))
        XCTAssertFalse(service.permits(b))
    }

    func testSensitiveSubmissionChecksBeforeSendingContent() async throws {
        var paths: [String] = []
        ReleaseAuditURLProtocol.handler = { request in
            paths.append(request.url!.path)
            let json = try JSONSerialization.jsonObject(with: Self.body(of: request)) as! [String: Any]
            XCTAssertEqual(Set(json.keys), ["p_topic_id"])
            return (200, Data("true".utf8))
        }
        let client = SupabaseHTTPClient(config: SupabaseConfig(baseURL: URL(string: "https://consent.invalid")!, anonKey: "test"),
                                        tokenProvider: nil, session: ReleaseAuditURLProtocol.session())
        let world = RemoteWorldService(client: client, currentUserID: { UUID() })
        do {
            try await world.submitWorldScore(topicId: UUID(), targetId: "general", score: 70,
                                             comment: "private political opinion", isAnonymous: false, countryCode: nil)
            XCTFail("Sensitive content must wait for separate consent")
        } catch { XCTAssertTrue(error.localizedDescription.contains("SENSITIVE_CONSENT_REQUIRED")) }
        XCTAssertEqual(paths.count, 1)
        XCTAssertTrue(paths[0].hasSuffix("needs_sensitive_consent"))
    }

    func testOrdinarySubmissionNeedsNoExtraConsent() async throws {
        var paths: [String] = []
        ReleaseAuditURLProtocol.handler = { request in
            paths.append(request.url!.path)
            return request.url!.path.hasSuffix("needs_sensitive_consent") ? (200, Data("false".utf8)) : (204, Data())
        }
        let client = SupabaseHTTPClient(config: SupabaseConfig(baseURL: URL(string: "https://consent.invalid")!, anonKey: "test"),
                                        tokenProvider: nil, session: ReleaseAuditURLProtocol.session())
        let user = UUID()
        let world = RemoteWorldService(client: client, currentUserID: { user })
        try await world.submitWorldScore(topicId: UUID(), targetId: "general", score: 70,
                                         comment: "ordinary comment", isAnonymous: false, countryCode: nil)
        XCTAssertEqual(paths.count, 2)
        XCTAssertTrue(paths.last!.hasSuffix("world_scores"))
    }

    nonisolated private static func body(of request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var result = Data(), buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            result.append(buffer, count: count)
        }
        return result
    }

}
