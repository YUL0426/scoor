import { SITE, STORE_STATUS, WAITLIST_URL } from "./site";

/** Platform detection (client-only). */
export function getPlatform(): "ios" | "android" | "web" {
  if (typeof navigator === "undefined") return "web";
  const ua = navigator.userAgent;
  if (/iphone|ipad|ipod/i.test(ua)) return "ios";
  if (/android/i.test(ua)) return "android";
  return "web";
}

function storeUrl(): string {
  // While the store listings aren't live, land on the download section
  // instead of a 404ing store page.
  if (getPlatform() === "android") {
    return STORE_STATUS.playStoreLive ? SITE.playStoreUrl : WAITLIST_URL;
  }
  return STORE_STATUS.appStoreLive ? SITE.appStoreUrl : WAITLIST_URL;
}

/**
 * Try to open the Scoor app via its custom scheme. If the app isn't
 * installed, the scheme silently fails and we fall back to the store after a
 * short delay (the page-visibility check cancels the fallback when the app
 * does take over, so installed users never bounce to the store).
 */
export function openInApp(path: string): void {
  const clean = path.replace(/^\/+/, "");
  const appUrl = `${SITE.scheme}://${clean}`;

  if (getPlatform() === "web") {
    window.location.href = storeUrl();
    return;
  }

  let fellBack = false;
  const fallback = window.setTimeout(() => {
    if (!fellBack && document.visibilityState === "visible") {
      window.location.href = storeUrl();
    }
  }, 1400);

  const cancel = () => {
    fellBack = true;
    window.clearTimeout(fallback);
  };
  // If the app opens, the page is backgrounded — cancel the store redirect.
  document.addEventListener("visibilitychange", cancel, { once: true });
  window.addEventListener("pagehide", cancel, { once: true });

  window.location.href = appUrl;
}
