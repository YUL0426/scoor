# Scoor — Marketing Landing Page

Instagram-quality consumer landing page for **Scoor**, the social scoring app.
Built to do three jobs: explain Scoor in 5 seconds, convert visitors into app
installs, and bridge web ↔ mobile with universal/deep links.

> "What score would you give it?"

---

## Stack

| Concern    | Choice |
| ---------- | ------ |
| Framework  | Next.js 16 (App Router, Turbopack) |
| Language   | TypeScript (strict) |
| Styling    | Tailwind CSS v4 (CSS-first `@theme`) |
| Motion     | Framer Motion 12 (+ GSAP available) |
| Icons      | lucide-react |
| Images     | `next/image` + `next/font` (Inter) |
| SEO        | Native App Router Metadata API + `next/og` |

> **On `next-seo` / `shadcn/ui`:** the brief listed both, but the App Router's
> native **Metadata API** supersedes `next-seo` (it's the officially
> recommended path and avoids a redundant dependency), and the few primitives
> we needed (`Button`, headings, badges) are hand-built with `cva` +
> `tailwind-merge` — the exact foundation shadcn generates — so the design
> system stays dependency-light and fully ours. Add shadcn components anytime
> with `npx shadcn@latest add …`; `lib/utils.ts` already exports the `cn()`
> helper it expects.

---

## Run it

```bash
cd landing
npm install
npm run dev      # http://localhost:3000
npm run build    # production build
npm start        # serve the production build
```

---

## Architecture

```
landing/
├── app/
│   ├── layout.tsx              # fonts, full SEO metadata, JSON-LD, theme color
│   ├── page.tsx                # composes the 8 landing sections
│   ├── globals.css             # design system: @theme tokens, keyframes, utilities
│   ├── opengraph-image.tsx     # dynamic 1200×630 OG image (next/og)
│   ├── twitter-image.tsx       # reuses the OG renderer
│   ├── sitemap.ts / robots.ts  # generated /sitemap.xml and /robots.txt
│   ├── manifest.ts             # PWA web manifest
│   ├── open/page.tsx           # universal-link bridge  (/open?to=score/123)
│   ├── score/[id]/page.tsx     # deep-link fallback  → scoor://score/:id
│   ├── user/[id]/page.tsx      # deep-link fallback  → scoor://user/:id
│   ├── topic/[id]/page.tsx     # deep-link fallback  → scoor://topic/:id
│   └── profile/page.tsx        # deep-link fallback  → scoor://profile
│
├── components/
│   ├── brand/ScoorWordmark.tsx     # official wordmark lockup (red / white)
│   ├── layout/                     # Navbar, Footer, SmartBanner, DeepLinkRedirect
│   ├── ui/                         # Button (cva), ScoreDial, SectionHeading, StoreBadges
│   ├── motion/                     # Reveal, ScoreCounter (scroll-triggered)
│   ├── screens/                    # PhoneFrame + AppScreens (6 recreated app screens)
│   └── sections/                   # the 8 page sections + MeshBackground
│
├── lib/
│   ├── site.ts        # single source of truth: URLs, IDs, scheme, deepLink()
│   ├── deeplink.ts    # client: getPlatform(), openInApp() with store fallback
│   ├── data.ts        # demo content mirroring real app surfaces
│   └── utils.ts       # cn(), scoreColor() ramp, scoreLabel(), formatCompact()
│
└── public/
    ├── scoor-wordmark-red.png / -white.png   # official cropped wordmarks
    ├── icon-192/512.png, apple-icon.png, icon.png
    └── .well-known/
        ├── apple-app-site-association        # iOS Universal Links
        └── assetlinks.json                   # Android App Links
```

### Landing sections (`app/page.tsx`)

1. **Hero** — animated phone (live Home screen), floating score cards, count-up stats
2. **HowItWorks** — Score → Explain → Track, 3 illustrated steps
3. **DailyLife** — infinite marquee of daily score cards
4. **WorldScores** — animated live sentiment heatmap + trending topics
5. **Insights** — animated trend chart, streaks, stat tiles
6. **SocialLayer** — feed posts, friends/followers/rankings
7. **ScreensShowcase** — autoplay + swipeable phone carousel (6 screens, parallax)
8. **DownloadCTA** — App Store / Play badges, QR code, deep-link button

---

## Design / Motion system

Everything funnels through `app/globals.css` `@theme`:

- **Brand red `#CE3B22`** — the official logo red (matches the iOS app's `Color.scoorRed`).
- **Score ramp** — `scoreColor(0–100)` in `lib/utils.ts` smoothly interpolates
  red → amber → green across the sentiment scale. Used everywhere a score is shown.
- **Motion** — `Reveal` (scroll fade/slide), `ScoreCounter` (count-up), `ScoreDial`
  (animated arc), marquee/float/blob keyframes. All respect
  `prefers-reduced-motion` (durations collapse to ~0).

The phone screens in `components/screens/AppScreens.tsx` are **recreated in React**
(not screenshots) so they're crisp at any DPI, animate, and stay in sync with the
real app's brand. Swap any screen for a real screenshot by dropping an image into
the relevant screen component.

---

## Web ↔ App integration

See **[DEEPLINKS.md](./DEEPLINKS.md)** for the full universal-link setup guide
(Apple AASA, Android assetlinks, Xcode/associated-domains, testing).

Quick map:

| URL                       | Opens in app            | If app missing |
| ------------------------- | ----------------------- | -------------- |
| `/open?to=score/123`      | `scoor://score/123`     | App Store      |
| `/score/123`              | `scoor://score/123`     | App Store      |
| `/user/456`               | `scoor://user/456`      | App Store      |
| `/topic/789`              | `scoor://topic/789`     | App Store      |
| `/profile`                | `scoor://profile`       | App Store      |

- **Smart Banner** — `components/layout/SmartBanner.tsx` shows only to mobile
  visitors; "Open" tries the app then falls back to the store. The native iOS
  banner is also enabled via `apple-itunes-app` meta in `app/layout.tsx`.
- **Fallback logic** — `lib/deeplink.ts#openInApp()` fires the scheme and, if the
  page is still visible after ~1.4s (app not installed), redirects to the
  platform store. If the app takes over, the visibility/pagehide listeners cancel
  the redirect so installed users never bounce.

---

## SEO checklist (all implemented)

- ✅ Title/description templates + canonical (`app/layout.tsx`)
- ✅ Target keywords: *score your day, daily rating app, life tracking app,
  social scoring app, public sentiment app*
- ✅ OpenGraph + Twitter `summary_large_image` with dynamic OG image
- ✅ `sitemap.xml`, `robots.txt`, PWA `manifest.webmanifest`
- ✅ JSON-LD `MobileApplication` structured data (rating, price, OS)
- ✅ Theme color, apple-web-app, favicons / apple-touch-icon

---

## Before launch — remaining steps

Apple team id (`G83W9HD6G7`) and bundle id (`com.euro.Scoor`) are already
wired into `lib/site.ts` and the AASA file. Still pending:

| Item | Where | Action |
| ---- | ----- | ------ |
| `appStoreId` | `lib/site.ts` | set the numeric id once the app exists in App Store Connect |
| `STORE_STATUS.appStoreLive` | `lib/site.ts` | flip to `true` when the listing is live (enables badges, smart banner, store fallback) |
| Android app | `lib/site.ts` + `.well-known/assetlinks.json` | when an Android app ships: flip `playStoreLive`, add `assetlinks.json` (see DEEPLINKS.md) |

---

## Deploy

Optimized for **Vercel** (`vercel deploy`). The OG/Twitter image routes use the
edge runtime; the `.well-known` files are served as static JSON with the correct
content type (configured in `next.config.ts`). Any Node host running
`next build && next start` works too.
