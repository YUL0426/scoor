# Spec 11 — Onboarding & Splash

> **Spec ID:** SPEC-11  
> **Priority:** P1  
> **Estimated Effort:** ~1.5 hours  
> **Dependencies:** SPEC-01, SPEC-03  

---

## Goal

Build the splash screen (app launch branding) and a 3-page onboarding walkthrough shown only on first launch.

---

## Files to Create

### `Views/Onboarding/SplashView.swift`

Animated branding screen shown at app launch.

### `Views/Onboarding/OnboardingView.swift`

Three-page walkthrough introducing the app's features.

### Modify `ScoorApp.swift`

Add routing logic:
- If first launch → show Onboarding
- Otherwise → show ContentView (tab bar)

---

## Splash Screen

### Visual Design

```
┌──────────────────────────────┐
│                              │
│                              │
│                              │
│         Scoor!               │  ← App name (large, bold)
│     ● ─ ─ ─ ─ ●             │  ← Subtle animation
│                              │
│   Your day, in one number    │  ← Tagline
│                              │
│                              │
│                              │
└──────────────────────────────┘
```

### Specs
- Background: White
- "Scoor!" text: Red, `.largeTitle`, bold
- Tagline: Gray, `.subheadline`
- Animation: Fade in → scale up over 1.5 seconds
- Duration: Display for 2 seconds, then auto-navigate
- No skip button

---

## Onboarding (3 Pages)

### Page 1 — Rate Your Day

```
┌──────────────────────────────┐
│                              │
│          ★                   │
│                              │
│    Rate Your Day             │
│                              │
│  Give your day a score       │
│  from 0 to 100.              │
│  That's it. Simple.          │
│                              │
│         ● ○ ○                │  ← Page indicator
│                              │
│      [ Next ]                │
└──────────────────────────────┘
```

### Page 2 — See the World

```
┌──────────────────────────────┐
│                              │
│          🌍                  │
│                              │
│    See the World             │
│                              │
│  Explore how people around   │
│  the globe are feeling       │
│  today.                      │
│                              │
│         ○ ● ○                │
│                              │
│      [ Next ]                │
└──────────────────────────────┘
```

### Page 3 — Track Your Journey

```
┌──────────────────────────────┐
│                              │
│          📊                  │
│                              │
│    Track Your Journey        │
│                              │
│  See trends, streaks, and    │
│  insights about your         │
│  emotional well-being.       │
│                              │
│         ○ ○ ●                │
│                              │
│   [ Get Started ]            │  ← Red filled button
└──────────────────────────────┘
```

---

## Onboarding Specs

| Element | Style |
|---|---|
| Icon | 64pt SF Symbol, Red color |
| Title | `.title`, bold, dark text |
| Body | `.body`, gray, centered, max width 280pt |
| Page indicator | Red dots (active) / Gray dots (inactive) |
| Next button | Text button, red |
| Get Started button | Full-width, Red background, White text |

### Navigation
- Swipe left/right between pages (TabView PageTabViewStyle)
- Next button advances to next page
- Get Started on page 3 → dismiss onboarding, show ContentView

### Persistence
- Store `hasCompletedOnboarding: Bool` in `UserDefaults`
- Check at app launch in `ScoorApp.swift`

---

## ScoorApp.swift Routing

```swift
@main
struct ScoorApp: App {
    @AppStorage("hasCompletedOnboarding") var hasCompleted = false
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView {
                    showSplash = false
                }
            } else if !hasCompleted {
                OnboardingView {
                    hasCompleted = true
                }
            } else {
                ContentView()
            }
        }
    }
}
```

---

## Acceptance Criteria

- [ ] Splash screen displays for 2 seconds with fade animation
- [ ] First-time users see onboarding after splash
- [ ] Onboarding has 3 swipeable pages
- [ ] Page indicators update correctly
- [ ] "Get Started" dismisses onboarding permanently
- [ ] Returning users skip onboarding and go straight to ContentView
- [ ] `hasCompletedOnboarding` is persisted in UserDefaults
