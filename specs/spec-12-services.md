# Spec 12 — Services & Networking Layer

> **Spec ID:** SPEC-12  
> **Priority:** P1  
> **Estimated Effort:** ~3 hours  
> **Dependencies:** SPEC-02  

---

## Goal

Build the service layer that abstracts data access behind protocols. In v1, all services use local storage (SwiftData). The protocol-based design allows easy replacement with a real backend later.

---

## Architecture

```
  ViewModel
      │
      ▼
  Protocol (e.g., ScoreServiceProtocol)
      │
      ├── LocalScoreService (SwiftData) ← v1
      └── RemoteScoreService (API)      ← future
```

---

## Files to Create

### `Services/ScoreService.swift`

```swift
protocol ScoreServiceProtocol {
    func saveScore(_ score: Score) async throws
    func updateScore(_ score: Score) async throws
    func getTodaysScore() async throws -> Score?
    func getScoreHistory(limit: Int?) async throws -> [Score]
    func getScores(for month: Date) async throws -> [Score]
}

class LocalScoreService: ScoreServiceProtocol {
    // SwiftData implementation
}
```

### `Services/WorldwideService.swift`

```swift
protocol WorldwideServiceProtocol {
    func getAggregatedScores(
        region: MKCoordinateRegion,
        zoomLevel: ZoomLevel
    ) async throws -> [ScoreAggregate]
    
    func getRegionScores(
        regionId: UUID,
        page: Int,
        pageSize: Int
    ) async throws -> [Score]
}

class MockWorldwideService: WorldwideServiceProtocol {
    // Returns hardcoded sample data in v1
}
```

### `Services/StatisticsService.swift`

```swift
protocol StatisticsServiceProtocol {
    func getStatistics(period: StatsPeriod) async throws -> ScoreStatistics
    func getCurrentStreak() async throws -> Int
    func getBestStreak() async throws -> Int
}

class LocalStatisticsService: StatisticsServiceProtocol {
    // Computes from local SwiftData store
}
```

### `Services/GuestbookService.swift`

```swift
protocol GuestbookServiceProtocol {
    func getMessages(
        for userId: UUID,
        includePrivate: Bool
    ) async throws -> [GuestbookMessage]
    
    func sendMessage(_ message: GuestbookMessage) async throws
    func deleteMessage(id: UUID) async throws
}

class MockGuestbookService: GuestbookServiceProtocol {
    // Returns sample messages in v1
}
```

### `Services/AuthService.swift`

```swift
protocol AuthServiceProtocol {
    func getCurrentUser() async throws -> User?
    func signUp(username: String, email: String) async throws -> User
    func signIn(email: String, password: String) async throws -> User
    func signOut() async throws
}

class LocalAuthService: AuthServiceProtocol {
    // Creates/stores a local user in v1
    // No real authentication yet
}
```

### `Services/LocationService.swift`

```swift
protocol LocationServiceProtocol {
    func getCurrentLocation() async throws -> Location?
    func requestPermission() async -> Bool
}

class DeviceLocationService: LocationServiceProtocol {
    // CoreLocation wrapper
}
```

---

## SwiftData Setup

### Model Container

Configure in `ScoorApp.swift`:

```swift
.modelContainer(for: [
    ScoreModel.self
])
```

### SwiftData Model: `ScoreModel`

```swift
@Model
class ScoreModel {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var value: Int
    var reason: String?
    var date: Date
    var locationId: UUID?
    var createdAt: Date
}
```

- Conversion methods: `ScoreModel.toScore()` and `Score.toModel()`
- Query descriptor sorted by `date` descending

---

## Dependency Injection

### ServiceContainer

```swift
class ServiceContainer: ObservableObject {
    let scoreService: ScoreServiceProtocol
    let worldwideService: WorldwideServiceProtocol
    let statisticsService: StatisticsServiceProtocol
    let guestbookService: GuestbookServiceProtocol
    let authService: AuthServiceProtocol
    let locationService: LocationServiceProtocol
    
    static let shared = ServiceContainer()
    
    init() {
        // v1: all local/mock implementations
        scoreService = LocalScoreService()
        worldwideService = MockWorldwideService()
        statisticsService = LocalStatisticsService()
        guestbookService = MockGuestbookService()
        authService = LocalAuthService()
        locationService = DeviceLocationService()
    }
}
```

Pass to view hierarchy via `.environmentObject(ServiceContainer.shared)`.

---

## Error Handling

```swift
enum ScoorError: LocalizedError {
    case scoreOutOfRange
    case reasonTooLong
    case scoreAlreadyExists
    case notAuthenticated
    case networkUnavailable
    case unknown(Error)
    
    var errorDescription: String? { ... }
}
```

---

## Acceptance Criteria

- [ ] All service protocols compile
- [ ] `LocalScoreService` saves and retrieves scores via SwiftData
- [ ] `MockWorldwideService` returns hardcoded sample data
- [ ] `LocalStatisticsService` computes correct averages and streaks
- [ ] `ServiceContainer` injects via `EnvironmentObject`
- [ ] All ViewModels use protocol types (not concrete classes)
- [ ] Error handling covers common failure cases
- [ ] SwiftData model container configured in `ScoorApp.swift`
