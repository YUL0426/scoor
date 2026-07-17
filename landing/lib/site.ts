/** Single source of truth for site-wide config, links, and deep-link scheme. */

export const SITE = {
  name: "Scoor",
  domain: "scoor.app",
  url: "https://scoor.app",
  tagline: "What score would you give it?",
  description:
    "Scoor is the social scoring app. Score your day, score the world, and see how everyone feels — 0 to 100, with a reason. Build your trends, follow friends, watch public sentiment move in real time.",
  // TODO(release): set once the app is provisioned in App Store Connect,
  // then flip appStoreLive to true.
  appStoreId: "",
  appStoreUrl: "https://apps.apple.com/app/scoor",
  playStoreUrl: "https://play.google.com/store/apps/details?id=com.euro.scoor",
  twitter: "@scoorapp",
  scheme: "scoor",
  // Apple App Site Association — must match the Xcode project
  // (PRODUCT_BUNDLE_IDENTIFIER = com.euro.Scoor, DEVELOPMENT_TEAM = G83W9HD6G7).
  appleTeamId: "G83W9HD6G7",
  appleBundleId: "com.euro.Scoor",
  androidPackage: "com.euro.scoor",
} as const;

/**
 * Store availability. While false, download surfaces render an honest
 * "Coming soon" state instead of linking to store pages that don't exist,
 * and the Smart App Banner meta tag is omitted.
 */
export const STORE_STATUS = {
  appStoreLive: false,
  playStoreLive: false, // no Android app yet
} as const;

/** Where "download" CTAs land while the store listings aren't live. */
export const WAITLIST_URL = `${SITE.url}/#download`;

/** Build a scoor:// deep link with an https universal-link fallback path. */
export function deepLink(path: string): { app: string; web: string } {
  const clean = path.replace(/^\/+/, "");
  return {
    app: `${SITE.scheme}://${clean}`,
    web: `${SITE.url}/${clean}`,
  };
}

export const DEEP_LINKS = {
  open: deepLink(""),
  score: (id: string | number) => deepLink(`score/${id}`),
  user: (id: string | number) => deepLink(`user/${id}`),
  topic: (id: string | number) => deepLink(`topic/${id}`),
  profile: deepLink("profile"),
};
