# Spec 10 — Guestbook (Tab 4 Sub-feature)

> **Spec ID:** SPEC-10  
> **Priority:** P0  
> **Estimated Effort:** ~2 hours  
> **Dependencies:** SPEC-02, SPEC-09  

---

## Goal

Build the Cyworld-style guestbook feature within the My Page tab. Users can leave public or private messages on each other's pages.

---

## Files to Create

### `Views/MyPage/GuestbookListView.swift`

Scrollable list of guestbook messages.

### `Views/MyPage/GuestbookComposeView.swift`

Compose screen for writing a new guestbook message.

### `ViewModels/GuestbookViewModel.swift`

Manages message list, compose state, and CRUD operations.

---

## UI Layout — Guestbook List

Embedded below the calendar in `MyPageView`:

```
┌──────────────────────────────┐
│  Guestbook (3)        ✏️     │  ← Section header + compose btn
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │ 🧑 @friend_01          │  │
│  │ "Have a great day!"    │  │  ← Public message
│  │ Mar 5 · Public         │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 🔒 @bestie_02          │  │
│  │ "Are you okay? DM me"  │  │  ← Private message
│  │ Mar 4 · Private        │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 🧑 @colleague_03       │  │
│  │ "Nice score yesterday!" │  │
│  │ Mar 3 · Public         │  │
│  └────────────────────────┘  │
│                              │
│  [ View All Messages ]       │
└──────────────────────────────┘
```

---

## Message Card

| Element | Style |
|---|---|
| Author avatar | 32pt circle |
| Username | `.subheadline`, bold |
| Message text | `.body`, max 3 lines, dark text |
| Timestamp | `.caption`, light gray |
| Visibility badge | "Public" or "Private" pill |
| Lock icon | 🔒 for private messages |

### Visibility Rules

| Viewer | Public Messages | Private Messages |
|---|---|---|
| Page owner | ✅ Visible | ✅ Visible |
| Other users | ✅ Visible | ❌ Hidden |

### Actions (long press menu)
- **Page owner:** Delete message
- **Message author:** Delete own message
- **Others:** Report message (placeholder)

---

## Compose View (`GuestbookComposeView`)

Presented as a sheet:

```
┌──────────────────────────────┐
│  Write a Message      Cancel │
├──────────────────────────────┤
│                              │
│  ┌────────────────────────┐  │
│  │ Type your message...   │  │  ← TextEditor
│  │                        │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
│  ┌──────────────────────┐    │
│  │ 🌐 Public    🔒 Private│  │  ← Toggle
│  └──────────────────────┘    │
│                              │
│  ┌────────────────────────┐  │
│  │      Send Message       │  │  ← Red button
│  └────────────────────────┘  │
└──────────────────────────────┘
```

### Fields

| Field | Spec |
|---|---|
| Message text | Required, max 500 characters, show counter |
| Visibility toggle | Public (default) / Private picker |
| Send button | Disabled if message is empty |

---

## ViewModel: `GuestbookViewModel`

### Published Properties

| Property | Type | Description |
|---|---|---|
| `messages` | `[GuestbookMessage]` | All visible messages |
| `composeText` | `String` | Current compose input |
| `isPrivate` | `Bool` | Visibility toggle state |
| `isComposing` | `Bool` | Show compose sheet |
| `isSending` | `Bool` | Loading state during send |

### Methods

| Method | Description |
|---|---|
| `loadMessages(for userId:)` | Fetch messages for a user's page |
| `sendMessage(to userId:)` | Post new message |
| `deleteMessage(_:)` | Remove a message |

### Sorting
- Messages sorted by `createdAt` descending
- Latest messages at the top

---

## Integration with MyPageView

- Guestbook section sits below the calendar in a `LazyVStack`
- Section header: "Guestbook (N)" with compose button (pencil icon)
- Initially shows last 3 messages
- "View All Messages" button expands to full list (or navigates to full page)

---

## Acceptance Criteria

- [ ] Guestbook section renders below calendar
- [ ] Public messages visible to all users
- [ ] Private messages visible only to page owner
- [ ] Compose sheet opens with text input and toggle
- [ ] Message validates (non-empty, ≤ 500 chars)
- [ ] Send button works and dismisses sheet
- [ ] Long press shows delete option for owner/author
- [ ] Messages sorted by newest first
- [ ] "View All Messages" shows full list
