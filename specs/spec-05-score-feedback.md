# Spec 05 — Score Feedback Engine

> **Spec ID:** SPEC-05  
> **Priority:** P1  
> **Estimated Effort:** ~1.5 hours  
> **Dependencies:** SPEC-02, SPEC-04  

---

## Goal

Build the feedback engine that generates contextual comparison messages after a user submits a score, and the animated bubble UI that displays them.

---

## Files to Create

### `Utilities/FeedbackEngine.swift`

Pure logic class (no UI) that takes the current score and historical data, then returns a feedback message.

### `Views/Score/ScoreFeedbackBubble.swift`

Animated bubble component that displays the feedback message.

---

## Feedback Logic

### Input
- `currentScore: Int` — today's submitted score
- `scoreHistory: [Score]` — all past scores sorted by date

### Decision Tree (priority order)

| # | Condition | Message Template | Example |
|---|---|---|---|
| 1 | First ever entry | `"Welcome! Your Scoor journey begins today. 🎉"` | — |
| 2 | Same day last week exists | `"X points higher/lower than last week!"` | "23 points higher than last week!" |
| 3 | Monthly average available | `"X points above/below your monthly average!"` | "7 points below your monthly average" |
| 4 | 3+ day upward streak | `"N-day upward streak! 🔥"` | "5-day upward streak! 🔥" |
| 5 | 3+ day downward streak | `"You've been trending down for N days. Hang in there 💪"` | — |
| 6 | Score ≥ 90 | `"What an amazing day! 🌟"` | — |
| 7 | Score ≤ 10 | `"Tough day. Tomorrow is a new start 🌅"` | — |
| 8 | Fallback (none of above) | `"Score recorded! Keep tracking. 📝"` | — |

### Rules
- Return **only one** message (highest priority match wins)
- `higher/lower` and `above/below` dynamically chosen based on comparison sign
- Streak = consecutive days where score increased (upward) or decreased (downward)
- "Same day last week" = 7 calendar days ago

### Method Signature

```swift
static func generateFeedback(
    currentScore: Int,
    history: [Score]
) -> FeedbackResult

struct FeedbackResult {
    let message: String
    let type: FeedbackType   // .positive, .neutral, .encouragement
}

enum FeedbackType {
    case positive       // green accent
    case neutral        // gray accent
    case encouragement  // warm orange accent
}
```

---

## Bubble UI: `ScoreFeedbackBubble`

### Visual Design

```
    ┌─────────────────────────────┐
    │  💬 23 points higher than   │
    │     last week!              │
    └──────────┬──────────────────┘
               ▽
         (speech bubble tail)
```

### Styling
- Background: White with thin border (color varies by `FeedbackType`)
  - `.positive` → green border + green emoji
  - `.neutral` → gray border
  - `.encouragement` → warm orange border
- Corner radius: 16pt
- Padding: 16pt horizontal, 12pt vertical
- Shadow: subtle drop shadow (2pt y-offset, 4pt blur)
- Font: `.subheadline`, medium weight

### Animation
- **Entry:** Slide up from bottom + fade in, spring animation (0.5s)
- **Auto-dismiss:** Fades out after 4 seconds
- **Manual dismiss:** Tap or swipe down to dismiss
- Use `withAnimation(.spring(response: 0.5, dampingFraction: 0.7))`

### Position
- Appears below the Submit button
- Centered horizontally

---

## Integration with SPEC-04

After `submitScore()` in `ScoreInputViewModel`:

```
1. Save score
2. Call FeedbackEngine.generateFeedback(currentScore:history:)
3. Set feedbackMessage to result
4. ScoreInputView shows ScoreFeedbackBubble
5. Bubble auto-dismisses after 4 seconds
```

---

## Acceptance Criteria

- [ ] First-time user sees welcome message
- [ ] Weekly comparison message is accurate
- [ ] Monthly average comparison is correct
- [ ] Streak detection works for 3+ consecutive days
- [ ] High score (≥90) and low score (≤10) messages display
- [ ] Bubble slides up with spring animation
- [ ] Bubble auto-dismisses after 4 seconds
- [ ] Bubble can be manually dismissed by tap
- [ ] Border color matches feedback type
