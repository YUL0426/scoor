//
//  PKCE.swift
//  Scoor
//
//  RFC 7636 (PKCE) + minimal JWT payload decoding helpers for the OAuth 2.0
//  authorization-code flow used by Google Sign-In. Pure & unit-testable.
//

import Foundation
import CryptoKit

enum PKCE {

    /// High-entropy code verifier — 43 chars (BASE64URL of 32 random bytes).
    static func makeCodeVerifier() -> String {
        base64URLEncode(randomBytes(32))
    }

    /// S256 code challenge = BASE64URL( SHA256( ASCII(verifier) ) ).
    static func codeChallengeS256(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    /// Opaque anti-CSRF state token.
    static func makeState() -> String {
        base64URLEncode(randomBytes(16))
    }

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        if SecRandomCopyBytes(kSecRandomDefault, count, &bytes) != errSecSuccess {
            // Fallback: still produce bytes (non-crypto) so the flow never traps.
            for i in 0..<count { bytes[i] = UInt8.random(in: .min ... .max) }
        }
        return Data(bytes)
    }
}

enum JWT {
    /// Decode the claims (payload) of a compact JWS without verifying the
    /// signature. Signature verification is the backend's responsibility; the
    /// client uses claims only to pre-fill profile fields (email/name/sub).
    static func decodePayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }
        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }
}

extension CharacterSet {
    /// Characters allowed unescaped in an `application/x-www-form-urlencoded` value.
    static let urlFormValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
