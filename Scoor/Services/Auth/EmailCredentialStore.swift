//
//  EmailCredentialStore.swift
//  Scoor
//
//  Device-local email/password account registry. Passwords are never stored or
//  transmitted in plain text: each account keeps a random salt + PBKDF2-HMAC-SHA256
//  hash in the Keychain. There is no backend yet, so accounts live on this device
//  only; the API shape mirrors a server credential endpoint so the swap stays
//  mechanical when one exists.
//

import Foundation
import CommonCrypto
import Security

enum EmailAuthOutcome: Equatable {
    case createdNewAccount
    case signedInExisting
}

enum EmailCredentialStore {

    private static let keyPrefix = "scoor.auth.emailcred."
    private static let defaultRounds: UInt32 = 120_000

    private struct Record: Codable {
        let salt: Data
        let hash: Data
        let rounds: UInt32
        let createdAt: Date
    }

    /// Normalize an email for identity purposes (trim + lowercase).
    static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func accountExists(email: String) -> Bool {
        KeychainStore.get(key(for: normalize(email))) != nil
    }

    /// Create the account if the email is new, otherwise verify the password
    /// against the stored hash. Throws when the password doesn't match.
    static func registerOrVerify(email: String, password: String) throws -> EmailAuthOutcome {
        let normalized = normalize(email)

        if let record = load(email: normalized) {
            let candidate = pbkdf2(password: password, salt: record.salt, rounds: record.rounds)
            guard constantTimeEquals(candidate, record.hash) else {
                throw AuthError.failed("이미 가입된 이메일입니다 — 비밀번호가 일치하지 않습니다.")
            }
            return .signedInExisting
        }

        var salt = Data(count: 16)
        let status = salt.withUnsafeMutableBytes { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
        }
        guard status == errSecSuccess else {
            throw AuthError.failed("보안 난수를 생성하지 못했습니다.")
        }

        let record = Record(
            salt: salt,
            hash: pbkdf2(password: password, salt: salt, rounds: defaultRounds),
            rounds: defaultRounds,
            createdAt: .now
        )
        guard let encoded = try? JSONEncoder().encode(record),
              let string = String(data: encoded, encoding: .utf8),
              KeychainStore.set(string, for: key(for: normalized)) else {
            throw AuthError.failed("자격 증명을 저장하지 못했습니다.")
        }
        return .createdNewAccount
    }

    /// Remove the stored credential (account deletion).
    static func removeAccount(email: String) {
        KeychainStore.delete(key(for: normalize(email)))
    }

    // MARK: - Private

    private static func key(for normalizedEmail: String) -> String {
        keyPrefix + normalizedEmail
    }

    private static func load(email normalizedEmail: String) -> Record? {
        guard let raw = KeychainStore.get(key(for: normalizedEmail)),
              let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Record.self, from: data)
    }

    static func pbkdf2(password: String, salt: Data, rounds: UInt32) -> Data {
        let passwordData = Data(password.utf8)
        var derived = Data(count: 32)
        derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                passwordData.withUnsafeBytes { passwordBuffer in
                    _ = CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        derivedBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }
        return derived
    }

    static func constantTimeEquals(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var diff: UInt8 = 0
        for (a, b) in zip(lhs, rhs) { diff |= a ^ b }
        return diff == 0
    }
}
