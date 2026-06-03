# Spec 04 — Score Input (Tab 1)

> **Spec ID:** SPEC-04  
> **Priority:** P0  
> **Estimated Effort:** ~2 hours  
> **Dependencies:** SPEC-01, SPEC-02, SPEC-03  

---

## Goal

Build the primary user interaction screen — the Score! tab — where users record their daily score (0–100) with an optional reason.

---

## Files to Create

### `Views/Score/ScoreInputView.swift`

The main view for Tab 1.

### `ViewModels/ScoreInputViewModel.swift`

Handles score input state, validation, persistence, and feedback generation.

---

## UI Layout (Top → Bottom)

```
┌──────────────────────────────┐
│         Scoor!               │  ← Title (large, bold)
│     "How was your day?"      │  ← Subtitle (gray)
│                              │
│  ┌────────────────────────┐  │
│  │                        │  │
│  │        [ 78 ]          │  │  ← Large score display
│  │                        │  │
│  │   ──────●──────────    │  │  ← Slider (0–100)
│  │    0              100  │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ Why this score?         │  │  ← Optional text field
│  │ (optional)              │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │     Submit Score        │  │  ← Red button
│  └────────────────────────┘  │
│                              │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐  │
│  │  Feedback Bubble        │  │  ← Appears after submit
│  │  "23 pts higher than…" │  │     (see SPEC-05)
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘  │
└──────────────────────────────┘
```

---

## Score Input Component

### Slider Behavior
- Range: 0–100, step: 1
- Thumb and track: Red accent (`Color.scoorRed`)
- Large centered number updates in real-time as slider moves
- Number font: `.system(size: 72, weight: .bold, design: .rounded)`

### Alternative Input
- User can also **tap the number** to type directly via numeric keyboard
- Keyboard type: `.numberPad`
- Input validation: clamp to 0–100

---

## Optional Reason Field

- Placeholder: *"Why this score? (optional)"*
- Max characters: 200
- Show character counter: `"42 / 200"`
- Rounded border, light gray background
- Single-line by default, expands to max 3 lines

---

## Submit Button

- Text: **"Submit Score"**
- Style: Full-width, rounded, red background, white text
- Disabled state: gray background (only when score hasn't changed from last submission)
- On tap:
  1. Save score to local storage
  2. Trigger haptic feedback (`.success`)
  3. Show feedback bubble (SPEC-05)
  4. Animate button → checkmark state for 2 seconds

---

## ViewModel: `ScoreInputViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `score` | `Int` | Current slider value (default: 50) |
| `reason` | `String` | Optional reason text |
| `isSubmitting` | `Bool` | Loading state |
| `isSubmitted` | `Bool` | True after today's score is saved |
| `feedbackMessage` | `String?` | Contextual bubble text (from SPEC-05) |
| `todaysScore` | `Score?` | Previously saved score for today |

### Methods

| Method | Description |
|---|---|
| `loadTodaysScore()` | Check if user already submitted today |
| `submitScore()` | Validate + save + generate feedback |
| `updateScore()` | Edit today's existing score |

### Business Rules

1. **One score per day:** If today's score exists, show it pre-filled and change button to "Update Score"
2. **Score resets at midnight:** `date` is calendar-day based (no time component)
3. **Reason is optional:** Can be nil or empty string

---

## Local Storage (v1)

- Use `SwiftData` via `@Model` or `UserDefaults` for MVP
- Store scores as an array indexed by date
- Will be replaced by backend sync in SPEC-12

---

## Acceptance Criteria

- [ ] Slider moves and updates displayed number in real-time
- [ ] Tapping the number opens numeric keypad
- [ ] Invalid input (outside 0–100) is clamped
- [ ] Reason field enforces 200 character limit
- [ ] Submit saves score with current date
- [ ] If today's score exists, pre-fill and show "Update Score"
- [ ] Haptic feedback on successful submit
- [ ] Button shows checkmark animation after submit
- [ ] View uses `Color.scoorRed` theming throughout
