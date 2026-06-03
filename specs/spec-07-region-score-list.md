# Spec 07 — Region Score List (Tab 2 Detail)

> **Spec ID:** SPEC-07  
> **Priority:** P0  
> **Estimated Effort:** ~1.5 hours  
> **Dependencies:** SPEC-02, SPEC-06  

---

## Goal

Build the Instagram DM-style score list that appears when a user taps a score bubble on the world map. Shows individual users' scores, short reflections, and timestamps for the selected region.

---

## Files to Create

### `Views/Worldwide/RegionScoreListView.swift`

Detail view presented as a sheet or push navigation from the map.

### `ViewModels/RegionScoreListViewModel.swift`

Fetches and manages individual score entries for a region.

---

## UI Layout

```
┌──────────────────────────────┐
│  ← Seoul, South Korea       │  ← Navigation title
│     Avg: 72 · 156 scores    │  ← Subtitle
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │ 🟢 @jina_park     85   │  │
│  │ "Great day at work!"   │  │  ← Score card
│  │ 2 hours ago            │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 🟡 @mike_lee      62   │  │
│  │ "Could be better"      │  │
│  │ 5 hours ago            │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 🔴 @soo_yeon      28   │  │
│  │                        │  │  ← No reason provided
│  │ 8 hours ago            │  │
│  └────────────────────────┘  │
│                              │
│  [ Load More ]               │  ← Pagination
└──────────────────────────────┘
```

---

## Score Card Component

Each card displays:

| Element | Style |
|---|---|
| Score color dot | 12pt circle, color-coded (same as map bubbles) |
| Username | `.subheadline`, bold, dark text |
| Score value | `.title3`, bold, right-aligned |
| Reason text | `.body`, gray, max 2 lines |
| Timestamp | `.caption`, light gray, relative ("2 hours ago") |

### Card Styling
- White background  
- 12pt corner radius  
- 1pt light gray border  
- 12pt vertical padding, 16pt horizontal  
- 8pt gap between cards  

---

## Header Section

- **Location name:** Bold, large title
- **Subtitle:** Average score + total count
- **Back button:** Standard navigation back (red tint)

---

## ViewModel: `RegionScoreListViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `regionName` | `String` | City or country name |
| `averageScore` | `Double` | Aggregate average |
| `totalCount` | `Int` | Total submissions |
| `scores` | `[Score]` | Individual score entries |
| `isLoading` | `Bool` | Fetch in progress |
| `hasMore` | `Bool` | More pages available |

### Methods

| Method | Description |
|---|---|
| `loadScores()` | Initial fetch (first page) |
| `loadMore()` | Fetch next page (append) |

### Pagination
- Page size: 20 entries
- Sorted by: `createdAt` descending (most recent first)
- Infinite scroll: trigger `loadMore()` when last item appears

---

## Presentation

- Presented as **`.sheet`** (half-height, detents: `.medium`, `.large`)
- Drag indicator visible at top
- Can be dismissed by swiping down

---

## Mock Data (v1)

Generate 50 mock score entries with:
- Random usernames (e.g., @user_001, @user_002)
- Random scores (0–100)
- Random reasons (some nil)
- Timestamps spread across last 24 hours

---

## Acceptance Criteria

- [ ] Sheet opens when tapping a map bubble
- [ ] Header shows region name, average, and count
- [ ] Score cards display username, score, reason, and timestamp
- [ ] Score dot color matches the score range
- [ ] Entries without a reason gracefully omit the text
- [ ] Infinite scroll loads more entries
- [ ] Sheet supports `.medium` and `.large` detents
- [ ] Swipe down dismisses the sheet
