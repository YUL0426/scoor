# Universal Links & Deep Links — Setup Guide

This site is the web half of Scoor's web ↔ app bridge. It handles three layers:

1. **Custom scheme** — `scoor://…` (works once the app is installed)
2. **Universal Links (iOS) / App Links (Android)** — `https://scoor.app/…` open
   the app directly, with no scheme prompt, when installed
3. **Web fallback** — if the app isn't installed, the same URL renders a branded
   "Opening Scoor…" page that routes the visitor to the App Store / Play Store

---

## 1. Link surface

| Intent          | Custom scheme        | Universal link (https)        |
| --------------- | -------------------- | ----------------------------- |
| Open app        | `scoor://`           | `https://scoor.app/open`      |
| A score         | `scoor://score/123`  | `https://scoor.app/score/123` |
| A user          | `scoor://user/456`   | `https://scoor.app/user/456`  |
| A world topic   | `scoor://topic/789`  | `https://scoor.app/topic/789` |
| Own profile     | `scoor://profile`    | `https://scoor.app/profile`   |
| Generic bridge  | —                    | `https://scoor.app/open?to=score/123` |

All of these are produced from one place — `lib/site.ts`:

```ts
DEEP_LINKS.score(123).app   // "scoor://score/123"
DEEP_LINKS.score(123).web   // "https://scoor.app/score/123"
```

---

## 2. iOS — Universal Links

### a. Web side (already done here)

`public/.well-known/apple-app-site-association` is served at
`https://scoor.app/.well-known/apple-app-site-association` as `application/json`
(no extension, no redirect — enforced in `next.config.ts`).

Replace `TEAMID1234.company.must.scoor` with your real
`<TeamID>.<BundleID>`.

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAMID1234.company.must.scoor",
      "paths": ["/score/*", "/user/*", "/topic/*", "/profile", "/open", "/open/*"]
    }]
  }
}
```

### b. App side (Xcode)

1. **Signing & Capabilities → + Capability → Associated Domains.**
2. Add: `applinks:scoor.app`
3. Handle the inbound URL in SwiftUI:

```swift
.onOpenURL { url in
    // scoor://score/123  (custom scheme)
    router.handle(url)
}
.onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
    // https://scoor.app/score/123  (universal link)
    if let url = activity.webpageURL { router.handle(url) }
}
```

4. Register the **custom scheme** too (Info → URL Types → URL Schemes → `scoor`)
   so `scoor://` links work as a fallback.

> Apple caches the AASA via its CDN. After deploying, validate at
> <https://app-site-association.cdn-apple.com/a/v1/scoor.app> and
> <https://search.developer.apple.com/appsearch-validation-tool/>.

---

## 3. Android — App Links

### a. Web side (already done here)

`public/.well-known/assetlinks.json` is served at
`https://scoor.app/.well-known/assetlinks.json`. Replace the fingerprint with
your **Play app-signing** SHA-256 (Play Console → Setup → App integrity):

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "company.must.scoor",
    "sha256_cert_fingerprints": ["AB:CD:…"]
  }
}]
```

### b. App side (Manifest)

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="scoor.app"
        android:pathPrefix="/score" />
  <!-- repeat <data> for /user, /topic, /profile, /open -->
</intent-filter>
```

Validate with:
`adb shell am start -a android.intent.action.VIEW -d "https://scoor.app/score/123"`

---

## 4. Fallback behaviour (web)

`lib/deeplink.ts#openInApp(path)`:

1. Detects platform (`ios` / `android` / `web`).
2. On mobile, navigates to `scoor://<path>` and starts a ~1.4s timer.
3. If the app opens, the tab is backgrounded → `visibilitychange` / `pagehide`
   **cancels** the timer (installed users never see the store).
4. If nothing happens (app missing), the timer fires → redirect to App Store /
   Play Store. On desktop it goes straight to the App Store.

The `/score/[id]`, `/user/[id]`, `/topic/[id]`, `/profile`, and `/open` routes
render `DeepLinkRedirect`, which runs this on mount and shows a branded spinner +
manual "Open in app" button + store badges as a guaranteed fallback. These routes
are `noindex` so they never compete with the marketing page in search.

---

## 5. Smart App Banner

- **Custom** (`components/layout/SmartBanner.tsx`): shown only to mobile UAs,
  dismissible (per session), "Open" runs `openInApp`.
- **Native iOS**: `apple-itunes-app` meta tag in `app/layout.tsx` — Safari shows
  Apple's official banner. Set the real `appStoreId` in `lib/site.ts`.

---

## 6. Testing matrix

| Case | Expected |
| ---- | -------- |
| iPhone w/ app, tap `scoor.app/score/1` | App opens to that score |
| iPhone w/o app, same link | Lands on fallback → App Store |
| Android w/ app (verified) | App opens directly |
| Desktop, tap a deep link | Redirects to App Store |
| Smart banner "Open", app installed | App opens |
| Smart banner "Open", app missing | Store |
