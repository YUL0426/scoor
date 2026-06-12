import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

/**
 * Realistic iPhone bezel with notch + status bar. Children render inside the
 * 9:19.5 viewport. Scales with `width`.
 */
export function PhoneFrame({
  children,
  width = 300,
  className,
  glare = true,
}: {
  children: ReactNode;
  width?: number;
  className?: string;
  glare?: boolean;
}) {
  const height = width * 2.06;
  return (
    <div
      className={cn("relative shrink-0", className)}
      style={{ width, height }}
    >
      {/* Titanium frame */}
      <div className="absolute inset-0 rounded-[18%/8.6%] bg-gradient-to-b from-[#3a3a40] via-[#1c1c20] to-[#0a0a0c] p-[3.5%] shadow-[0_40px_80px_-24px_rgba(0,0,0,0.55),0_8px_24px_-8px_rgba(0,0,0,0.4)]">
        {/* Inner screen */}
        <div className="relative h-full w-full overflow-hidden rounded-[15%/7.2%] bg-[var(--color-paper)]">
          {/* Status bar */}
          <div className="absolute inset-x-0 top-0 z-30 flex items-center justify-between px-6 pt-3 text-[10px] font-semibold text-[var(--color-ink)]">
            <span>9:41</span>
            <div className="flex items-center gap-1">
              <svg width="16" height="11" viewBox="0 0 16 11" fill="currentColor"><rect x="0" y="6" width="3" height="5" rx="1"/><rect x="4" y="4" width="3" height="7" rx="1"/><rect x="8" y="2" width="3" height="9" rx="1"/><rect x="12" y="0" width="3" height="11" rx="1"/></svg>
              <svg width="22" height="11" viewBox="0 0 24 12" fill="none"><rect x="1" y="1" width="20" height="10" rx="3" stroke="currentColor" strokeWidth="1" opacity="0.5"/><rect x="2.5" y="2.5" width="15" height="7" rx="1.5" fill="currentColor"/><rect x="22" y="4" width="1.5" height="4" rx="0.75" fill="currentColor" opacity="0.5"/></svg>
            </div>
          </div>

          {/* Dynamic Island / notch */}
          <div className="absolute left-1/2 top-[2.4%] z-40 h-[3.4%] w-[34%] -translate-x-1/2 rounded-full bg-black" />

          {/* Screen content */}
          <div className="relative h-full w-full overflow-hidden">{children}</div>

          {/* Glass glare */}
          {glare && (
            <div className="pointer-events-none absolute inset-0 z-50 bg-gradient-to-tr from-transparent via-white/0 to-white/10" />
          )}
        </div>
      </div>
    </div>
  );
}
