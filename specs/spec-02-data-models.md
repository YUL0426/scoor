# Spec 02 — Data Models

> **Spec ID:** SPEC-02  
> **Priority:** P0 (Prerequisite)  
> **Estimated Effort:** ~45 minutes  
> **Dependencies:** SPEC-01 (project exists)  

---

## Goal

Define all core data models with `Codable`, `Identifiable`, and `Hashable` conformance. These models are the foundation for every feature in the app.

---

## Files to Create

### `Models/User.swift`

```swift
struct User: Codable, Identifiable, Hashable {
    let id: UUID
    var username: String
    var email: String
    var avatarURL: URL?
    let createdAt: Date
}
```

### `Models/Score.swift`

```swift
struct Score: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var value: Int          // 0–100
    var reason: String?     // max 200 chars
    let date: Date          // calendar day (no time)
    var locationId: UUID?
    let createdAt: Date
}
```

**Validation rules:**
- `value` must be in 0...100
- `reason` must be ≤ 200 characters (or nil)
- `date` should be date-only (time stripped)

### `Models/Location.swift`

```swift
struct Location: Codable, Identifiable, Hashable {
    let id: UUID
    let country: String
    let city: String
    let latitude: Double
    let longitude: Double
}
```

### `Models/GuestbookMessage.swift`

```swift
struct GuestbookMessage: Codable, Identifiable, Hashable {
    let id: UUID
    let authorId: UUID
    let recipientId: UUID
    var content: String
    var isPrivate: Bool
    let createdAt: Date
}
```

---

## Supporting Types

### `Models/ScoreAggregate.swift`

Used for worldwide map bubbles:

```swift
struct ScoreAggregate: Codable, Identifiable {
    let id: UUID
    let location: Location
    let averageScore: Double
    let totalCount: Int
    let period: Date
}
```

### `Models/StatsPeriod.swift`

Enum for statistics time range:

```swift
enum StatsPeriod: String, CaseIterable {
    case daily
    case weekly
    case monthly
}
```

### `Models/ScoreStatistics.swift`

```swift
struct ScoreStatistics {
    let period: StatsPeriod
    let averageScore: Double
    let highestScore: Int
    let lowestScore: Int
    let totalEntries: Int
    let currentStreak: Int
    let scores: [Score]
}
```

---

## Acceptance Criteria

- [ ] All models compile without errors
- [ ] All models conform to `Codable`, `Identifiable`
- [ ] `Score.value` validation logic works (clamp or throw)
- [ ] `Score.reason` respects 200-character limit
- [ ] `PreviewData` updated to use these real model types
- [ ] Models can be encoded to / decoded from JSON
