//
//  SupabaseConfig.swift
//  Scoor
//
//  Backend provisioning check. Mirrors the GIDClientID pattern: the values come
//  from Config/Secrets.xcconfig → Config/Info.plist, and when they are absent the
//  app degrades to local-only (SwiftData) instead of failing. That keeps previews,
//  unit tests, and fresh checkouts building with no backend at all — the same
//  reason Google Sign-In hides its button rather than crashing.
//

import Foundation

struct SupabaseConfig: Equatable {

    let baseURL: URL
    let anonKey: String

    /// REST (PostgREST) root — table access.
    var restURL: URL { baseURL.appendingPathComponent("rest/v1") }
    /// GoTrue root — sign-in, token refresh, account deletion.
    var authURL: URL { baseURL.appendingPathComponent("auth/v1") }
    /// Edge Functions root.
    var functionsURL: URL { baseURL.appendingPathComponent("functions/v1") }

    // MARK: - Provisioning

    /// Config for this build, or nil when the backend is not provisioned.
    static let current: SupabaseConfig? = resolve {
        Bundle.main.object(forInfoDictionaryKey: $0) as? String
    }

    /// Whether this build talks to a backend at all. Call sites use this to pick
    /// between the Remote and local-only service stacks.
    static var isProvisioned: Bool { current != nil }

    /// Resolve from an Info.plist-shaped lookup. Takes a closure rather than a
    /// `Bundle` because `Bundle` is a class cluster and cannot be meaningfully
    /// subclassed for tests.
    static func resolve(value: (String) -> String?) -> SupabaseConfig? {
        guard let host = provisioned(value("SupabaseHost")),
              let key = provisioned(value("SupabaseAnonKey")),
              // A scheme in the host means someone pasted the full Project URL
              // despite the xcconfig limitation; strip it rather than build
              // "https://https://…".
              let url = URL(string: "https://" + host.replacingOccurrences(
                  of: #"^https?://"#, with: "", options: .regularExpression))
        else { return nil }
        return SupabaseConfig(baseURL: url, anonKey: key)
    }

    /// Info.plist values stay unexpanded (`$(SUPABASE_HOST)`) when the xcconfig
    /// var is empty, so a non-nil read does not mean "provisioned" — treat the
    /// placeholder as absent.
    private static func provisioned(_ raw: String?) -> String? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty, !value.hasPrefix("$(")
        else { return nil }
        return value
    }
}
