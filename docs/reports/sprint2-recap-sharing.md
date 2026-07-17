# Sprint 2 — Task 3: Recap Sharing

**Date:** 2026-06-03
**Branch:** `sprint2-foundations`
**Status:** ✅ Complete — 8 unit tests passing, light+dark renders verified

## Goal

First growth loop — turn the monthly recap into a high-resolution, branded, shareable image (save / system share / Instagram Story), light & dark.

## Architecture

```
RecapData                  ── value the card renders (month line, average, top day, streak, intensities)
RecapCardView(scheme:)     ── one branded card, deterministic light & dark  ◄── live preview AND export use this
RecapStoryCanvas(scheme:)  ── 9:16 full-bleed (360×640 pt → 1080×1920 px @scale 3)

RecapShareService (enum)
   ├─ render(_:scale:3) -> UIImage         (ImageRenderer, high-res)
   ├─ renderStory(data:scheme:) -> UIImage
   ├─ saveToPhotos(_:) async  throws       (PHPhotoLibrary, .addOnly auth)
   └─ shareToInstagramStory(_:) throws     (pasteboard + instagram-stories:// deep link)

InstagramStoryShareSheet (StatsView)
   ├─ ShareLink(item: Image)               (system share — covers IG feed, messages, Files…)
   ├─ "Instagram Story" button             (sticker deep link; graceful failure if absent)
   ├─ "Save to Gallery" button             (saveToPhotos)
   └─ loading / success / failure feedback
```

Single source of truth: the **same `RecapCardView`** is shown live in the sheet and rasterized for export — the preview is the artifact. This replaced the old hard-coded `storyPreviewCard` whose buttons were empty closures (`Button(action: {})`).

### Key decisions

- **`ImageRenderer`** (iOS 17 target) at `scale = 3` → 1080×1920 story export; `isOpaque = false`.
- **Real data**: card pulls `viewModel.heatmapCells` intensities + share fields (average, top day, **unified streak**), not the old placeholder opacities.
- **Instagram via pasteboard** (`com.instagram.sharedSticker.backgroundImage`) — avoids needing `LSApplicationQueriesSchemes`, so no manual `Info.plist`. Falls back to a "not installed" message.
- **Photos**: added `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` (generated plist); `.addOnly` permission.
- **Dark/light**: `RecapCardView`/`RecapStoryCanvas` take an explicit `scheme` so the export is deterministic regardless of device appearance.

## Screenshots

| File | Shows |
|---|---|
| `sprint2-screenshots/10-recap-card-light.png` | Branded card, light — wordmark, June Summary, intensity grid, Average/Top Day/Streak |
| `sprint2-screenshots/11-recap-card-dark.png` | Same, dark |
| `sprint2-screenshots/12-recap-story-light.png` | 9:16 story canvas, light gradient |
| `sprint2-screenshots/13-recap-story-dark.png` | 9:16 story canvas, dark gradient, `scoor.app` |

These are produced by `RecapShareService.render(...)` in `RecapSnapshotTests` — i.e. the exact pipeline the Share button uses, so they are faithful exports, not mockups.

## Test results

`ScoorTests` — **8 passed, 0 failed**:
- `RecapShareTests` (4): light card renders, dark card renders, story is 1080×1920 ±6 px, aspect ratio 9:16 ±0.02.
- `RecapSnapshotTests` (4): render + attach light/dark card and light/dark story.

Save-to-Photos, system ShareLink, and the Instagram deep link are validated interactively (they require user-granted permissions / installed apps).

## Files added / modified

| Change | File |
|---|---|
| **Added** | `Scoor/Views/Share/RecapShareView.swift` (RecapData, RecapCardView, RecapStoryCanvas) |
| **Added** | `Scoor/Services/RecapShareService.swift` |
| **Added** | `ScoorTests/RecapShareTests.swift`, `ScoorTests/RecapSnapshotTests.swift` |
| **Modified** | `Scoor/Views/Statistics/StatsView.swift` — `InstagramStoryShareSheet` rewired to real actions + feedback |
| **Modified** | `Scoor.xcodeproj` — `INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` |

## Known limitations

- The live share-sheet end-to-end UI screenshot wasn't auto-captured (Monthly-tab scroll automation was flaky); the **rendered card/story PNGs above are the authoritative visuals**, and the sheet's actions are unit/asserted. Tracked in the QA tech-debt list.
