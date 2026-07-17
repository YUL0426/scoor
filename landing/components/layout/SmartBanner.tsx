"use client";

import { useEffect, useState } from "react";
import { X } from "lucide-react";
import { SITE, STORE_STATUS } from "@/lib/site";
import { openInApp } from "@/lib/deeplink";

const DISMISS_KEY = "scoor-smartbanner-dismissed";

/**
 * App-install banner for mobile visitors only. Tapping "Open" attempts the
 * scoor:// deep link and falls back to the store if the app isn't installed.
 */
export function SmartBanner() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    // No banner while the store listing isn't live — "Free on the App Store"
    // would be a dead-end claim.
    if (!STORE_STATUS.appStoreLive) return;
    const isMobile = /android|iphone|ipad|ipod/i.test(navigator.userAgent);
    const dismissed = sessionStorage.getItem(DISMISS_KEY);
    if (isMobile && !dismissed) setShow(true);
  }, []);

  if (!show) return null;

  return (
    <div className="fixed inset-x-0 top-0 z-[60] flex items-center gap-3 border-b border-[var(--color-line)] bg-white/95 px-3 py-2.5 backdrop-blur md:hidden">
      <button
        aria-label="Dismiss"
        onClick={() => {
          sessionStorage.setItem(DISMISS_KEY, "1");
          setShow(false);
        }}
        className="grid h-7 w-7 place-items-center rounded-full text-[var(--color-text-3)]"
      >
        <X size={16} />
      </button>
      <div className="grid h-10 w-10 place-items-center rounded-[10px] bg-[var(--color-brand)] text-lg font-bold text-white">
        82
      </div>
      <div className="min-w-0 flex-1 leading-tight">
        <p className="truncate text-[13px] font-semibold">{SITE.name}</p>
        <p className="truncate text-[11px] text-[var(--color-text-3)]">
          Score your day. Free on the App Store.
        </p>
      </div>
      <button
        onClick={() => openInApp("")}
        className="rounded-full bg-[var(--color-brand)] px-4 py-1.5 text-[13px] font-semibold text-white"
      >
        Open
      </button>
    </div>
  );
}
