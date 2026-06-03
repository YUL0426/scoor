# Spec 06 — Worldwide Map (Tab 2)

> **Spec ID:** SPEC-06  
> **Priority:** P0  
> **Estimated Effort:** ~3 hours  
> **Dependencies:** SPEC-01, SPEC-02, SPEC-03  

---

## Goal

Build the interactive world map where users can explore aggregated scores from around the world. Score bubbles are displayed over countries (zoom level 1) and cities (zoom level 2).

---

## Files to Create

### `Views/Worldwide/WorldMapView.swift`

Main map view using MapKit.

### `Views/Worldwide/ScoreBubbleAnnotation.swift`

Custom map annotation showing score value inside a colored circle.

### `ViewModels/WorldMapViewModel.swift`

Manages map region, zoom level detection, and data fetching.

---

## UI Layout

```
┌──────────────────────────────┐
│  Worldwide Scoor      🔍     │  ← Title bar
├──────────────────────────────┤
│                              │
│     ┌──┐                     │
│     │72│   ┌──┐              │  ← Score bubbles
│     └──┘   │65│              │     on map
│            └──┘   ┌──┐      │
│                   │81│      │
│        ┌──┐       └──┘      │
│        │45│                  │
│        └──┘                  │
│                              │
│    [Interactive MapKit Map]  │
│                              │
└──────────────────────────────┘
```

---

## Map Configuration

### Framework
- Use `Map` from MapKit (iOS 17+)
- Initial region: World view (center: 0°, 0°; span: 120° lat, 360° lng)

### Zoom Levels

| Zoom | Span (latitude) | Data Shown | Annotation Size |
|---|---|---|---|
| Level 1 | > 15° | Country averages | 44pt circle |
| Level 2 | ≤ 15° | City averages | 36pt circle |

- Detect zoom level via `MKCoordinateRegion.span.latitudeDelta`
- When zoom changes, re-fetch data for visible region

---

## Score Bubble Annotation

### Visual Design

```
  ┌─────┐
  │ 72  │   ← Score number (bold, white text)
  └─────┘
      ↑
  Circle with color based on score:
```

### Color Coding

| Score Range | Color | Hex |
|---|---|---|
| 80–100 | Green | `#4CAF50` |
| 60–79 | Yellow-Green | `#8BC34A` |
| 40–59 | Yellow | `#FFC107` |
| 20–39 | Orange | `#FF9800` |
| 0–19 | Red | `#F44336` |

### Bubble Properties
- Size: 44pt (country) / 36pt (city)
- Font: `.caption`, bold
- Text: White
- Shadow: 2pt drop shadow
- Animation: Subtle scale-in when appearing

### Tap Action
- On tap → navigate to `RegionScoreListView` (SPEC-07)
- Pass region ID and location name

---

## ViewModel: `WorldMapViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `region` | `MKCoordinateRegion` | Current visible map region |
| `zoomLevel` | `ZoomLevel` | `.country` or `.city` |
| `annotations` | `[ScoreAggregate]` | Score data for visible region |
| `isLoading` | `Bool` | Data fetch in progress |
| `selectedAnnotation` | `ScoreAggregate?` | Currently tapped bubble |

### Methods

| Method | Description |
|---|---|
| `onRegionChange(_:)` | Detect zoom level, debounce, fetch data |
| `fetchScores(for:zoom:)` | Load aggregated scores for visible region |
| `selectAnnotation(_:)` | Set selected annotation for navigation |

### Zoom Level Detection

```swift
enum ZoomLevel {
    case country  // span.latitudeDelta > 15
    case city     // span.latitudeDelta <= 15
}
```

### Debouncing
- Region changes fire rapidly during pan/zoom
- Debounce fetch calls by 500ms using `Task` + `Task.sleep`

---

## Mock Data (v1)

Until SPEC-12 provides a real backend, use hardcoded sample data:
- 15–20 country-level aggregates (major countries)
- 30–40 city-level aggregates for 5–6 countries
- Randomized average scores between 30–85

---

## Acceptance Criteria

- [ ] Map renders full-screen below title bar
- [ ] Country score bubbles appear at zoom level 1
- [ ] City score bubbles appear at zoom level 2
- [ ] Bubble colors match score range
- [ ] Tapping a bubble triggers navigation to SPEC-07
- [ ] Map pan/zoom is smooth (no jank from frequent fetches)
- [ ] Debounce prevents excessive data requests
- [ ] Bubbles animate in when they appear
