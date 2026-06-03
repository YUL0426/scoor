# Spec 09 — My Page & Calendar (Tab 4)

> **Spec ID:** SPEC-09  
> **Priority:** P0  
> **Estimated Effort:** ~2.5 hours  
> **Dependencies:** SPEC-01, SPEC-02, SPEC-03  

---

## Goal

Build the My Page tab with a profile header and interactive calendar that visually displays daily scores across a month. Tapping a day shows its details.

---

## Files to Create

### `Views/MyPage/MyPageView.swift`

Main container for Tab 4.

### `Views/MyPage/CalendarGridView.swift`

Monthly calendar grid with colored day cells.

### `Views/MyPage/CalendarDayCell.swift`

Individual day cell component.

### `Views/MyPage/CalendarDetailView.swift`

Detail view for a tapped day.

### `ViewModels/MyPageViewModel.swift`

Manages profile data, calendar state, and month navigation.

---

## UI Layout

```
┌──────────────────────────────┐
│  ┌──┐                  ⚙️   │
│  │🧑│  @username             │  ← Profile header
│  └──┘  Joined Mar 2026      │
│        Score avg: 72         │
├──────────────────────────────┤
│                              │
│  ◀  March 2026  ▶          │  ← Month navigator
│                              │
│  Mo Tu We Th Fr Sa Su        │
│  ┌──┬──┬──┬──┬──┬──┬──┐    │
│  │  │  │  │  │  │01│02│    │
│  │  │  │  │  │  │72│85│    │  ← Score in cell
│  ├──┼──┼──┼──┼──┼──┼──┤    │
│  │03│04│05│06│07│  │  │    │
│  │91│45│68│  │77│  │  │    │  ← Empty = no score
│  └──┴──┴──┴──┴──┴──┴──┘    │
│  ... (more weeks)            │
│                              │
├──────────────────────────────┤
│  Guestbook Section           │  ← (See SPEC-10)
└──────────────────────────────┘
```

---

## Profile Header

| Element | Style |
|---|---|
| Avatar | 56pt circle, placeholder image |
| Username | `.title3`, bold |
| Join date | `.caption`, gray |
| Average score | `.subheadline`, red badge |
| Settings gear | Top-right, navigates to SettingsView |

---

## Calendar Grid

### Month Navigation
- Left/right chevrons to switch months
- Current month + year displayed as title
- Animated slide transition on month change

### Day Cell (`CalendarDayCell`)

| State | Appearance |
|---|---|
| **Has score** | Day number + small score text, background colored by score |
| **No score** | Day number only, light gray background |
| **Today** | Red border ring |
| **Future date** | Dimmed, non-tappable |

### Cell Color Mapping

| Score Range | Background Color | Opacity |
|---|---|---|
| 80–100 | Green | 0.7 |
| 60–79 | Yellow-Green | 0.5 |
| 40–59 | Yellow | 0.4 |
| 20–39 | Orange | 0.5 |
| 0–19 | Red | 0.6 |
| No score | Light Gray | 0.3 |

### Cell Size
- Fixed grid: 7 columns
- Cell size: calculated to fill screen width with 4pt gaps
- Each cell: square, 8pt corner radius

### Tap Interaction
- Tapping a day with a score → opens `CalendarDetailView`
- Tapping an empty day → no action (or prompt to score if today)

---

## CalendarDetailView

Presented as a sheet (`.medium` detent):

```
┌──────────────────────────────┐
│  March 5, 2026               │  ← Date
│                              │
│         ┌───┐                │
│         │ 68│                │  ← Large score
│         └───┘                │
│                              │
│  "Had a productive morning   │
│   but tired in the evening"  │  ← Reason
│                              │
│  Recorded at 9:42 PM         │  ← Timestamp
└──────────────────────────────┘
```

---

## ViewModel: `MyPageViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `user` | `User` | Current user profile |
| `currentMonth` | `Date` | Displayed month |
| `monthScores` | `[Date: Score]` | Scores indexed by date for current month |
| `overallAverage` | `Double` | All-time average score |
| `selectedDay` | `Score?` | Tapped day's score for detail view |

### Methods

| Method | Description |
|---|---|
| `loadProfile()` | Fetch user data |
| `loadMonth(_:)` | Fetch scores for displayed month |
| `previousMonth()` | Navigate to previous month |
| `nextMonth()` | Navigate to next month |
| `selectDay(_:)` | Open detail for tapped day |

---

## Acceptance Criteria

- [ ] Profile header displays avatar, username, join date, average
- [ ] Calendar renders correct days for the current month
- [ ] Day cells are colored based on score value
- [ ] Today has a red border ring
- [ ] Future dates are dimmed and non-tappable
- [ ] Month navigation with chevrons works with animation
- [ ] Tapping a scored day opens CalendarDetailView
- [ ] Detail view shows score, reason, and timestamp
- [ ] Settings gear icon navigates to SettingsView
