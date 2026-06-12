//
//  MoodAnalyzing.swift
//  Scoor
//
//  Sprint 2-A (revised) — Mood is a DERIVED field, not a user input.
//  The user records only a Scoor (score) and an optional reason; the emotion
//  is inferred afterwards by analysis and written back into the existing
//  `Score.mood` / `ScoreModel.moodRaw` fields.
//
//  This file defines the architectural SEAM for that future derivation. It is
//  intentionally NOT wired into the live save path yet — enabling it is a
//  separate, explicit step (see "Wiring" note below) so current behavior is
//  unchanged and no moods are auto-generated until the product opts in.
//
//  ┌─────────────┐   score + reason   ┌──────────────────┐   Mood?   ┌────────────────────┐
//  │ Score save  │ ─────────────────▶ │  MoodAnalyzing    │ ───────▶ │ persist moodRaw     │
//  │ (user input)│                    │  (rule / AI)      │          │ (same SwiftData col) │
//  └─────────────┘                    └──────────────────┘          └────────────────────┘
//
//  Wiring (future Sprint 2-B):
//   • Inject a `MoodAnalyzing` into `AppServices` (default `DisabledMoodAnalyzer`).
//   • After `ScoreServiceProtocol.saveScore`, call `analyze(score:reason:)` and,
//     if non-nil, write the derived mood back (a second save / dedicated update),
//     OR run a background backfill over `getScoreHistory` for entries with nil mood.
//   • Swap `RuleBasedMoodAnalyzer` for an AI/LLM-backed implementation behind the
//     same protocol with zero changes to call sites.
//

import Foundation

/// Derives an emotion (`Mood`) for a recorded Scoor. Implementations may be
/// rule-based (on-device, fast) or AI/remote (async). `async` keeps the
/// contract identical for both. Returns `nil` when there is no confident signal.
protocol MoodAnalyzing {
    func analyze(score: Int, reason: String?) async -> Mood?
}

/// Current default — derivation disabled. Produces no mood so new entries stay
/// emotion-free until the product explicitly enables analysis.
struct DisabledMoodAnalyzer: MoodAnalyzing {
    func analyze(score: Int, reason: String?) async -> Mood? { nil }
}

/// Lightweight, dependency-free on-device classifier: reason keyword signals
/// first, then a score-band fallback. Functional and unit-testable so it can
/// ship as the v1 derivation and later be replaced by an AI sentiment model
/// behind the same `MoodAnalyzing` protocol.
struct RuleBasedMoodAnalyzer: MoodAnalyzing {

    /// Keyword → mood signals (Korean + English), highest precedence first.
    private static let keywordRules: [(keys: [String], mood: Mood)] = [
        (["사랑", "설렘", "love", "crush"], .love),
        (["번아웃", "지침", "탈진", "burnout", "exhausted", "drained"], .burnout),
        (["외로", "쓸쓸", "lonely", "alone"], .lonely),
        (["회복", "휴식", "쉼", "healing", "rest", "recharge"], .healing),
        (["새벽", "불면", "잠", "night", "insomnia"], .night),
        (["공부", "시험", "학교", "study", "exam", "school"], .students),
        (["업무", "회의", "야근", "work", "meeting", "deadline"], .work),
        (["평온", "고요", "차분", "calm", "peace"], .calm),
        (["행복", "기쁨", "happy", "joy", "great"], .happy),
    ]

    func analyze(score: Int, reason: String?) async -> Mood? {
        let text = (reason ?? "").lowercased()

        // 1) Reason keyword signal.
        for rule in Self.keywordRules where rule.keys.contains(where: text.contains) {
            return rule.mood
        }

        // 2) Score-band fallback (only when there is something to classify).
        guard !text.isEmpty || score > 0 else { return nil }
        switch score {
        case 75...100: return .happy
        case 55..<75:  return .calm
        case 35..<55:  return .lonely
        case 1..<35:   return .burnout
        default:       return nil
        }
    }
}
