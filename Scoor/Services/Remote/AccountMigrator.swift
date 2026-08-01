//
//  AccountMigrator.swift
//  Scoor
//
//  One-time adoption of pre-login data by a signed-in account (spec-13 §7).
//
//  Signing in changes who owns the local rows. A guest journals under a
//  device-local UUID; once authenticated the account id becomes the server's
//  `auth.users.id`. Every screen reads by the *current* id, so without this step
//  the history is still on disk but invisible — indistinguishable from data loss
//  by the person looking at an empty calendar — and it never reaches the server.
//
//  Three things happen, in order of how badly they matter:
//    1. Local rows are re-keyed to the account (scores + guestbook). Local, so it
//       works with no network and cannot be lost.
//    2. Those rows are queued for upload. Durable outbox, so an offline sign-in
//       still backs up later.
//    3. The local profile (nickname / emoji / bio) is pushed to `profiles`.
//       Network-only, and the one step allowed to fail and retry.
//
//  Idempotent per account: each part records its own completion flag, so a partial
//  run resumes rather than repeating work or double-uploading.
//

import Foundation

@MainActor
final class AccountMigrator {

    /// Bump when the migration itself changes shape and must run again.
    private static let version = "v1"

    private let scoreService: ScoreServiceProtocol
    private let guestbookService: GuestbookServiceProtocol
    private let userService: UserServiceProtocol
    /// Nil when the backend is not provisioned — the local re-key still runs, which
    /// is exactly what an un-provisioned build needs (the id changes there too).
    private let remoteScoreService: RemoteScoreService?
    private let client: SupabaseHTTPClient?
    private let defaults: UserDefaults

    init(scoreService: ScoreServiceProtocol,
         guestbookService: GuestbookServiceProtocol,
         userService: UserServiceProtocol,
         remoteScoreService: RemoteScoreService? = nil,
         client: SupabaseHTTPClient? = nil,
         defaults: UserDefaults = .standard) {
        self.scoreService = scoreService
        self.guestbookService = guestbookService
        self.userService = userService
        self.remoteScoreService = remoteScoreService
        self.client = client
        self.defaults = defaults
    }

    // MARK: - Entry point

    /// Adopt local data for `accountUserID`. Safe to call on every sign-in.
    ///
    /// - Parameter previousUserID: the id local rows are currently keyed to,
    ///   captured *before* the profile adopted the account id.
    func migrateIfNeeded(from previousUserID: UUID?, to accountUserID: UUID) async {
        await adoptLocalRows(from: previousUserID, to: accountUserID)
        await uploadProfileIfNeeded(for: accountUserID)
    }

    // MARK: - 1 & 2. Local re-key + backfill

    private func adoptLocalRows(from previousUserID: UUID?, to accountUserID: UUID) async {
        let key = flagKey("adopted", accountUserID)
        guard !defaults.bool(forKey: key) else { return }

        if let previousUserID, previousUserID != accountUserID {
            do {
                let moved = try await scoreService.reassignScores(from: previousUserID, to: accountUserID)
                #if DEBUG
                print("[Scoor] AccountMigrator re-keyed \(moved.count) scores → \(accountUserID)")
                #endif
            } catch {
                // Leave the flag unset so the next sign-in retries. Nothing was
                // lost: the rows are still under the previous id.
                #if DEBUG
                print("[Scoor] AccountMigrator score re-key failed: \(error.localizedDescription)")
                #endif
                return
            }

            try? await guestbookService.reassignMessages(from: previousUserID, to: accountUserID)
        }

        // Covers history that already carries the account id but was written before
        // the sync layer existed — a re-key moves nothing there, yet none of it has
        // ever been queued for upload.
        await remoteScoreService?.enqueueBackfill(userId: accountUserID)

        defaults.set(true, forKey: key)
    }

    // MARK: - 3. Profile upload

    /// Push the locally chosen nickname / emoji / bio onto the server profile row
    /// (created by the sign-up trigger with a placeholder username).
    ///
    /// A taken username is not an error worth blocking on: the server keeps the one
    /// it generated and the user can rename later. Failing the whole migration over
    /// a name collision would strand the far more valuable score history.
    private func uploadProfileIfNeeded(for accountUserID: UUID) async {
        guard let client else { return }
        let key = flagKey("profile", accountUserID)
        guard !defaults.bool(forKey: key) else { return }

        guard let user = await userService.getCurrentUser() else { return }
        let emoji = await userService.currentAvatarEmoji()

        let username = Self.sanitizedUsername(user.username)
        let patch = ProfilePatch(
            username: username,
            avatarEmoji: emoji,
            bio: user.bio.flatMap { $0.isEmpty ? nil : $0 }
        )
        // Nothing local worth sending — don't overwrite the server row with nils.
        guard patch.hasContent else {
            defaults.set(true, forKey: key)
            return
        }

        do {
            try await client.send(
                try .update("profiles",
                            values: patch,
                            filters: ["id": SupabaseRequest.eq(accountUserID.uuidString.lowercased())])
            )
            defaults.set(true, forKey: key)
        } catch APIError.rejected {
            // Username taken or a check constraint refused it. Retrying will fail
            // identically, so treat it as settled and keep the server's values.
            defaults.set(true, forKey: key)
            #if DEBUG
            print("[Scoor] AccountMigrator profile patch rejected — keeping server profile")
            #endif
        } catch {
            // Offline / transient: leave the flag unset and try again next launch.
            #if DEBUG
            print("[Scoor] AccountMigrator profile upload deferred: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Helpers

    private func flagKey(_ part: String, _ userID: UUID) -> String {
        "scoor.migration.\(Self.version).\(part).\(userID.uuidString)"
    }

    /// `profiles.username` is `check (char_length between 2 and 20)` and unique.
    /// The local default ("scoor_user") and anything out of range is dropped rather
    /// than sent — a rejected patch would cost the profile fields that *are* valid.
    static func sanitizedUsername(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != "scoor_user", (2...20).contains(trimmed.count) else { return nil }
        return trimmed
    }
}

// MARK: - Wire model

/// PATCH body for `public.profiles`. Every field optional — omitted keys are left
/// untouched by PostgREST, which is what makes this a patch and not a replace.
struct ProfilePatch: Encodable {
    let username: String?
    let avatarEmoji: String?
    let bio: String?

    var hasContent: Bool { username != nil || avatarEmoji != nil || bio != nil }

    enum CodingKeys: String, CodingKey {
        case username
        case avatarEmoji = "avatar_emoji"
        case bio
    }

    /// Encode only the keys that carry a value, so a nil bio does not blank out a
    /// bio the user already set on another device.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let username { try container.encode(username, forKey: .username) }
        if let avatarEmoji { try container.encode(avatarEmoji, forKey: .avatarEmoji) }
        if let bio { try container.encode(bio, forKey: .bio) }
    }
}
