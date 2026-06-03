# Spec 08 — Statistics Dashboard (Tab 3)

> **Spec ID:** SPEC-08  
> **Priority:** P0  
> **Estimated Effort:** ~3 hours  
> **Dependencies:** SPEC-01, SPEC-02, SPEC-03  

---

## Goal

Build the Statistics tab with interactive charts showing score trends, distribution, averages, and streaks across daily, weekly, and monthly time ranges.

---

## Files to Create

### `Views/Statistics/StatisticsView.swift`

Main container view for Tab 3.

### `Views/Statistics/TrendLineChart.swift`

Line chart showing score over time.

### `Views/Statistics/DistributionChart.swift`

Histogram showing score frequency distribution.

### `Views/Statistics/AverageScoreCard.swift`

Prominent card displaying average score.

### `Views/Statistics/StreakCard.swift`

Card showing current and best streaks.

### `ViewModels/StatisticsViewModel.swift`

Computes all statistical data from score history.

### `Services/StatisticsService.swift`

Extracts stats computation into a testable service.

---

## UI Layout

```
┌──────────────────────────────┐
│  Statistics                  │  ← Title
├──────────────────────────────┤
│  [ Daily | Weekly | Monthly ]│  ← Segmented picker
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │     Average Score      │  │
│  │        ┌───┐           │  │
│  │        │ 72│           │  │  ← AverageScoreCard
│  │        └───┘           │  │
│  │  ▲ 5 from last period  │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  Score Trend            │  │
│  │  📈 ───────────────    │  │  ← TrendLineChart
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  ┌───────────┬────────────┐  │
│  │  🔥 Streak │ 📊 Distrib.│  │  ← Side by side
│  │    12 days │  [bars]    │  │
│  └───────────┴────────────┘  │
│                              │
└──────────────────────────────┘
```

---

## Period Selector

- SwiftUI `Picker` with `.segmented` style
- Options: **Daily**, **Weekly**, **Monthly**
- Red tint for selected segment
- Switching periods re-computes all stats with animation

### Period Definitions

| Period | Data Range | Chart X-axis |
|---|---|---|
| Daily | Last 7 days | Day names (Mon, Tue…) |
| Weekly | Last 4 weeks | "Week 1", "Week 2"… |
| Monthly | Last 6 months | Month names (Jan, Feb…) |

---

## Components

### AverageScoreCard

- Large centered number: `.system(size: 48, weight: .bold)`
- Label: "Average Score"
- Delta indicator: ▲ or ▼ with point difference from previous period
  - ▲ green if higher
  - ▼ red if lower
- White card, rounded corners, subtle shadow

### TrendLineChart

- Uses **Swift Charts** framework (`import Charts`)
- `LineMark` with `PointMark` overlay
- Line color: `Color.scoorRed`
- Point color: `Color.scoorRed`
- Y-axis: 0–100 (fixed range)
- X-axis: varies by period
- Grid lines: light gray, dashed
- Area fill: red gradient, 10% opacity
- Chart height: 200pt

### DistributionChart

- `BarMark` histogram
- Buckets: 0–20, 21–40, 41–60, 61–80, 81–100
- Bar color: `Color.scoorRed` with varying opacity
- Chart height: 150pt
- X-axis labels: score ranges
- Y-axis labels: count

### StreakCard

- Current streak: number + "days" label
- Best streak: smaller text below
- Fire emoji (🔥) when streak ≥ 3
- Definition: consecutive calendar days with a submitted score

---

## ViewModel: `StatisticsViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `selectedPeriod` | `StatsPeriod` | Current selected period |
| `averageScore` | `Double` | Average for selected period |
| `averageDelta` | `Double` | Change vs. previous period |
| `trendData` | `[(Date, Int)]` | Data points for line chart |
| `distributionData` | `[(String, Int)]` | Bucket → count for histogram |
| `currentStreak` | `Int` | Current consecutive days |
| `bestStreak` | `Int` | All-time best streak |
| `isLoading` | `Bool` | Loading state |

### Methods

| Method | Description |
|---|---|
| `loadStats()` | Compute all stats for current period |
| `onPeriodChange(_:)` | Re-compute when period changes |

---

## Empty State

If no data exists for the selected period:

```
┌────────────────────────────┐
│                            │
│      📊                    │
│  No data yet               │
│  Start scoring to see      │
│  your statistics!           │
│                            │
│  [Go to Score! →]          │  ← Links to Tab 1
└────────────────────────────┘
```

---

## Acceptance Criteria

- [ ] Segmented picker toggles between Daily/Weekly/Monthly
- [ ] Average score card shows correct value and delta
- [ ] Trend line chart renders with correct data points
- [ ] Distribution histogram shows 5 buckets
- [ ] Streak card displays current and best streaks
- [ ] All charts use `Color.scoorRed` theming
- [ ] Period change triggers animated transition
- [ ] Empty state displayed when no data exists
- [ ] Charts use Swift Charts framework (iOS 16+)
