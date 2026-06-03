# Spec 01 — Project Setup & Design Theme

> **Spec ID:** SPEC-01  
> **Priority:** P0 (Prerequisite)  
> **Estimated Effort:** ~1 hour  
> **Dependencies:** None  

---

## Goal

Initialize the Xcode project, establish folder structure, and configure the global design system (colors, typography, spacing) so all subsequent specs can build on a consistent foundation.

---

## Scope

### In Scope
- Create Xcode project (iOS, SwiftUI lifecycle)
- Set deployment target: iOS 17.0+
- Create all folder groups matching Plan.md structure
- Define design tokens (colors, fonts, spacing)
- Set up asset catalog with brand colors
- Create `PreviewData.swift` with sample data stubs

### Out of Scope
- Any feature views (handled in SPEC-03 through SPEC-11)
- Backend/networking setup (handled in SPEC-12)
- Data model files (handled in SPEC-02)

---

## Folder Structure to Create

```
Scoor/
├── ScoorApp.swift
├── ContentView.swift
├── Models/
├── ViewModels/
├── Views/
│   ├── Score/
│   ├── Worldwide/
│   ├── Statistics/
│   ├── MyPage/
│   ├── Onboarding/
│   └── Settings/
├── Services/
├── Utilities/
│   └── Extensions/
├── Resources/
│   └── Assets.xcassets/
└── Preview Content/
```

---

## Files to Create

### `Utilities/Extensions/Color+Theme.swift`

Define the following color constants:

| Token | Hex | Usage |
|---|---|---|
| `Color.scoorRed` | `#E53935` | Primary actions, active tab, buttons |
| `Color.scoorRedLight` | `#FF8A80` | Accents, highlights, gradients |
| `Color.scoorWhite` | `#FFFFFF` | Backgrounds |
| `Color.scoorGray` | `#9E9E9E` | Inactive tabs, secondary text |
| `Color.scoorDarkText` | `#212121` | Primary text |
| `Color.scoorLightGray` | `#F5F5F5` | Card backgrounds, dividers |

### `Utilities/Constants.swift`

Define app-wide constants:

```
- scoreRange: 0...100
- maxReasonLength: 200
- appName: "Scoor!"
- animationDuration: 0.3
```

### `Utilities/Extensions/Date+Formatting.swift`

Date formatters:
- `shortDate` → "Mar 7"
- `fullDate` → "March 7, 2026"
- `timeAgo` → "2 hours ago"

### `Utilities/Extensions/View+Modifiers.swift`

Custom ViewModifiers:
- `.scoorCard()` → white background, rounded corners, subtle shadow
- `.scoorButton()` → red background, white text, rounded

### `Preview Content/PreviewData.swift`

Stub factory methods returning sample data for SwiftUI previews:
- `PreviewData.sampleUser`
- `PreviewData.sampleScore`
- `PreviewData.sampleScores` (array of 30 days)
- `PreviewData.sampleGuestbookMessage`

---

## Acceptance Criteria

- [ ] Xcode project builds without errors
- [ ] All folder groups exist in project navigator
- [ ] `Color.scoorRed` renders correctly in a preview
- [ ] `PreviewData.sampleUser` returns a valid stub
- [ ] No external dependencies installed yet
