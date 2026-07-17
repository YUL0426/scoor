//
//  AuthServiceTests.swift
//  ScoorTests
//
//  Unit coverage for the account system's pure building blocks: PKCE (against the
//  RFC 7636 test vector), deterministic account → local-id mapping, and JWT claim
//  decoding used to pre-fill the profile from a Google id_token.
//

import XCTest
@testable import Scoor

final class AuthServiceTests: XCTestCase {

    // MARK: - PKCE (RFC 7636 Appendix B test vector)

    func testPKCEChallengeMatchesRFC7636Vector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let expectedChallenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
        XCTAssertEqual(PKCE.codeChallengeS256(for: verifier), expectedChallenge)
    }

    func testPKCEVerifierIsURLSafeAndStable() {
        let verifier = PKCE.makeCodeVerifier()
        // BASE64URL of 32 bytes → 43 chars, no padding/url-unsafe characters.
        XCTAssertEqual(verifier.count, 43)
        XCTAssertFalse(verifier.contains("+"))
        XCTAssertFalse(verifier.contains("/"))
        XCTAssertFalse(verifier.contains("="))
        // Challenge is deterministic for a given verifier.
        XCTAssertEqual(PKCE.codeChallengeS256(for: verifier), PKCE.codeChallengeS256(for: verifier))
    }

    func testPKCEStateIsRandom() {
        XCTAssertNotEqual(PKCE.makeState(), PKCE.makeState())
    }

    // MARK: - Deterministic account → local id mapping

    func testStableUserIDIsDeterministicPerAccount() {
        let a = AuthenticatedIdentity(provider: .apple, providerUserID: "000123.abcDEF")
        let b = AuthenticatedIdentity(provider: .apple, providerUserID: "000123.abcDEF")
        XCTAssertEqual(a.stableUserID, b.stableUserID, "같은 계정은 항상 같은 로컬 id로 매핑되어야 함")
    }

    func testStableUserIDDiffersByProviderAndSubject() {
        let apple = AuthenticatedIdentity(provider: .apple, providerUserID: "same")
        let google = AuthenticatedIdentity(provider: .google, providerUserID: "same")
        let other = AuthenticatedIdentity(provider: .apple, providerUserID: "different")
        XCTAssertNotEqual(apple.stableUserID, google.stableUserID)
        XCTAssertNotEqual(apple.stableUserID, other.stableUserID)
    }

    func testDeterministicUUIDHasVersion5AndRFC4122Variant() {
        let uuid = AuthenticatedIdentity.deterministicUUID(from: "apple:subject")
        let bytes = withUnsafeBytes(of: uuid.uuid) { Array($0) }
        XCTAssertEqual(bytes[6] & 0xF0, 0x50, "version nibble must be 5")
        XCTAssertEqual(bytes[8] & 0xC0, 0x80, "variant bits must be RFC 4122")
    }

    // MARK: - Email credential store (P0-2 / P0-7)

    func testEmailRegisterThenVerifyRoundTrip() throws {
        let email = "unit-test-\(UUID().uuidString)@scoor.app"
        defer { EmailCredentialStore.removeAccount(email: email) }

        XCTAssertEqual(
            try EmailCredentialStore.registerOrVerify(email: email, password: "secret123"),
            .createdNewAccount
        )
        XCTAssertEqual(
            try EmailCredentialStore.registerOrVerify(email: email, password: "secret123"),
            .signedInExisting
        )
        XCTAssertThrowsError(
            try EmailCredentialStore.registerOrVerify(email: email, password: "wrong-pass"),
            "기존 계정에 다른 비밀번호는 거부되어야 함"
        )
    }

    func testEmailIdentityIsDeterministicAndCaseInsensitive() {
        let a = AuthenticatedIdentity(provider: .email, providerUserID: EmailCredentialStore.normalize("Me@Scoor.App"))
        let b = AuthenticatedIdentity(provider: .email, providerUserID: EmailCredentialStore.normalize(" me@scoor.app "))
        XCTAssertEqual(a.stableUserID, b.stableUserID, "같은 이메일은 로그아웃 후에도 같은 로컬 id로 복원되어야 함")
    }

    // MARK: - JWT claim decoding (Google id_token)

    func testJWTDecodePayloadExtractsClaims() {
        // header.payload.signature — payload = {"sub":"42","email":"qa@scoor.app","name":"Scoor QA"}
        let payload = #"{"sub":"42","email":"qa@scoor.app","name":"Scoor QA"}"#
        let payloadB64 = PKCE.base64URLEncode(Data(payload.utf8))
        let token = "header.\(payloadB64).signature"

        let claims = JWT.decodePayload(token)
        XCTAssertEqual(claims?["sub"] as? String, "42")
        XCTAssertEqual(claims?["email"] as? String, "qa@scoor.app")
        XCTAssertEqual(claims?["name"] as? String, "Scoor QA")
    }

    func testJWTDecodeReturnsNilForMalformedToken() {
        XCTAssertNil(JWT.decodePayload("not-a-jwt"))
    }
}
