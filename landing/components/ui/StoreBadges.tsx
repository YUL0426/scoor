import type { ReactNode } from "react";
import { SITE, STORE_STATUS } from "@/lib/site";
import { cn } from "@/lib/utils";

/**
 * While a store listing isn't live (STORE_STATUS), badges render as a
 * non-clickable "Coming soon" state instead of linking to a page that 404s.
 */
function BadgeShell({
  live,
  href,
  ariaLabel,
  className,
  children,
}: {
  live: boolean;
  href: string;
  ariaLabel: string;
  className?: string;
  children: ReactNode;
}) {
  const base =
    "inline-flex h-14 items-center gap-3 rounded-2xl bg-[var(--color-ink)] px-5 text-white";
  if (!live) {
    return (
      <span
        aria-label={`${ariaLabel} — coming soon`}
        className={cn(base, "cursor-default opacity-60", className)}
      >
        {children}
      </span>
    );
  }
  return (
    <a
      href={href}
      aria-label={ariaLabel}
      className={cn(
        base,
        "transition-transform duration-300 hover:-translate-y-0.5",
        className
      )}
    >
      {children}
    </a>
  );
}

/** Official-style Apple App Store badge, inline SVG (crisp at any size). */
export function AppStoreBadge({ className }: { className?: string }) {
  return (
    <BadgeShell
      live={STORE_STATUS.appStoreLive}
      href={SITE.appStoreUrl}
      ariaLabel="Download Scoor on the App Store"
      className={className}
    >
      <svg viewBox="0 0 24 24" width="26" height="26" fill="currentColor" aria-hidden>
        <path d="M16.365 1.43c0 1.14-.42 2.2-1.18 3.01-.86.96-2.27 1.71-3.4 1.62-.13-1.1.42-2.27 1.1-3 .77-.84 2.2-1.5 3.32-1.55.02.31.16.61.16.92zM20.9 17.07c-.6 1.39-.9 2-1.67 3.23-1.08 1.72-2.6 3.87-4.49 3.88-1.67.02-2.1-1.09-4.37-1.08-2.27.01-2.74 1.1-4.42 1.08-1.88-.02-3.32-1.95-4.4-3.67C-1 16.43-1.32 9.9 1.95 7.6c1.16-.83 2.6-1.28 3.8-1.28 1.22 0 2.4.55 3.4.55.98 0 2.5-.68 4.04-.58.64.03 2.45.26 3.62 1.96-3.18 1.94-2.67 6.47.09 7.82z" />
      </svg>
      <span className="flex flex-col leading-none">
        <span className="text-[10px] font-medium opacity-80">
          {STORE_STATUS.appStoreLive ? "Download on the" : "Coming soon to the"}
        </span>
        <span className="text-lg font-semibold tracking-tight">App Store</span>
      </span>
    </BadgeShell>
  );
}

/** Google Play badge (dark), inline SVG. */
export function PlayStoreBadge({ className }: { className?: string }) {
  return (
    <BadgeShell
      live={STORE_STATUS.playStoreLive}
      href={SITE.playStoreUrl}
      ariaLabel="Get Scoor on Google Play"
      className={className}
    >
      <svg viewBox="0 0 24 24" width="24" height="24" aria-hidden>
        <path fill="#34d27e" d="M3.6 1.8 13.4 12 3.6 22.2A2 2 0 0 1 3 20.8V3.2c0-.55.24-1.05.6-1.4z" />
        <path fill="#5bc9f4" d="m16.5 8.9 2.9 1.65c1.5.85 1.5 2.95 0 3.8L16.5 16l-3.1-3.1z" />
        <path fill="#fce000" d="M13.4 12 16.5 16 5.4 22.3c-.5.28-1.07.27-1.5.02L13.4 12z" />
        <path fill="#ee4e4e" d="M3.9 1.68c.43-.25 1-.26 1.5.02L16.5 8 13.4 12 3.9 1.68z" />
      </svg>
      <span className="flex flex-col leading-none">
        <span className="text-[10px] font-medium opacity-80">
          {STORE_STATUS.playStoreLive ? "GET IT ON" : "COMING SOON TO"}
        </span>
        <span className="text-lg font-semibold tracking-tight">Google Play</span>
      </span>
    </BadgeShell>
  );
}

/**
 * QR code that resolves to the universal link. Uses a QR image endpoint;
 * swap the `src` for a self-hosted/static QR in production if you prefer no
 * third-party dependency.
 */
export function DownloadQR({ size = 132 }: { size?: number }) {
  const data = encodeURIComponent(SITE.url);
  return (
    <div className="rounded-2xl bg-white p-3 shadow-[0_8px_30px_-12px_rgba(0,0,0,0.25)] ring-1 ring-[var(--color-line)]">
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={`https://api.qrserver.com/v1/create-qr-code/?size=${size * 2}x${size * 2}&margin=0&color=14141a&data=${data}`}
        alt="Scan to open Scoor"
        width={size}
        height={size}
        className="rounded-lg"
      />
    </div>
  );
}
