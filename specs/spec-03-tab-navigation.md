# Spec 03 — Tab Shell & Navigation

> **Spec ID:** SPEC-03  
> **Priority:** P0 (Prerequisite)  
> **Estimated Effort:** ~30 minutes  
> **Dependencies:** SPEC-01  

---

## Goal

Build the root `TabView` with 4 tabs. Each tab shows a placeholder view initially. This establishes the app's navigation skeleton so individual features can be developed independently.

---

## Files to Modify

### `ContentView.swift`

Implement a `TabView` with 4 tabs:

| Tab | Label | SF Symbol | Placeholder Text |
|---|---|---|---|
| 1 | Score! | `star.circle.fill` | "Score Input" |
| 2 | Worldwide | `globe` | "World Map" |
| 3 | Statistics | `chart.bar.fill` | "Statistics" |
| 4 | My Page | `person.crop.circle` | "My Page" |

### Tab Bar Styling

- **Active tab:** Red (`Color.scoorRed`) icon + label
- **Inactive tab:** Gray (`Color.scoorGray`) icon only
- **Background:** White with subtle top border (0.5pt gray line)
- Use `.tint(Color.scoorRed)` on TabView

### State Management

- `@State private var selectedTab: Int = 0`
- Tab selection persists during app session

---

## UI Specification

```
┌──────────────────────────────┐
│                              │
│                              │
│     [Placeholder Content]    │
│                              │
│                              │
├──────────────────────────────┤
│  ★ Score!  🌐   📊   👤     │  ← Tab Bar
└──────────────────────────────┘
```

---

## Acceptance Criteria

- [ ] App launches and shows tab bar with 4 tabs
- [ ] Tapping each tab switches the content area
- [ ] Active tab shows red icon + label
- [ ] Inactive tabs show gray icon, no label
- [ ] Tab bar has white background with top border
- [ ] First tab (Score!) is selected by default
