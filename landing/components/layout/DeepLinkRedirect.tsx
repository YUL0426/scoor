"use client";

import { useEffect } from "react";
import { ScoorWordmark } from "@/components/brand/ScoorWordmark";
import { AppStoreBadge, PlayStoreBadge } from "@/components/ui/StoreBadges";
import { openInApp } from "@/lib/deeplink";

/**
 * Universal-link bridge. On mount it tries to open the native app at `path`
 * (scoor://path). If the app is installed, iOS/Android hand off before this
 * page is even seen. If not, the user lands here and falls through to the
 * store — and a manual "Open in app" button covers browsers that block the
 * auto-attempt.
 */
export function DeepLinkRedirect({
  path,
  title,
}: {
  path: string;
  title: string;
}) {
  useEffect(() => {
    const t = setTimeout(() => openInApp(path), 300);
    return () => clearTimeout(t);
  }, [path]);

  return (
    <main className="grid min-h-dvh place-items-center bg-[var(--color-canvas)] px-6 text-center">
      <div className="flex flex-col items-center">
        <ScoorWordmark height={30} priority />
        <div className="mt-8 h-10 w-10 animate-spin rounded-full border-[3px] border-[var(--color-line-strong)] border-t-[var(--color-brand)]" />
        <h1 className="mt-6 text-xl font-bold tracking-tight">Opening {title} in Scoor…</h1>
        <p className="mt-2 max-w-xs text-sm text-[var(--color-text-2)]">
          If nothing happens, you don&apos;t have the app yet. Grab it below — it&apos;s free.
        </p>

        <button
          onClick={() => openInApp(path)}
          className="mt-6 rounded-full bg-[var(--color-brand)] px-6 py-3 text-sm font-semibold text-white transition-transform hover:-translate-y-0.5"
        >
          Open in app
        </button>

        <div className="mt-5 flex flex-wrap justify-center gap-3">
          <AppStoreBadge />
          <PlayStoreBadge />
        </div>

        <a href="/" className="mt-8 text-sm text-[var(--color-text-3)] underline-offset-4 hover:underline">
          ← Back to scoor.app
        </a>
      </div>
    </main>
  );
}
