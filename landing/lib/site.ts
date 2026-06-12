/** Single source of truth for site-wide config, links, and deep-link scheme. */

export const SITE = {
  name: "Scoor",
  domain: "scoor.app",
  url: "https://scoor.app",
  tagline: "What score would you give it?",
  description:
    "Scoor is the social scoring app. Score your day, score the world, and see how everyone feels — 0 to 100, with a reason. Build your trends, follow friends, watch public sentiment move in real time.",
  // Replace with the real App Store id once provisioned.
  appStoreId: "0000000000",
  appStoreUrl: "https://apps.apple.com/app/scoor/id0000000000",
  playStoreUrl: "https://play.google.com/store/apps/details?id=company.must.scoor",
  twitter: "@scoorapp",
  scheme: "scoor",
  // Apple App Site Association
  appleTeamId: "TEAMID1234",
  appleBundleId: "company.must.scoor",
  androidPackage: "company.must.scoor",
} as const;

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
