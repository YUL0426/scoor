"use client";

import { useEffect, useState, useCallback } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { PhoneFrame } from "@/components/screens/PhoneFrame";
import { AppScreen } from "@/components/screens/AppScreens";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { SHOWCASE_SCREENS } from "@/lib/data";
import { cn } from "@/lib/utils";

const AUTOPLAY_MS = 3200;

export function ScreensShowcase() {
  const [index, setIndex] = useState(0);
  const [dir, setDir] = useState(1);
  const [paused, setPaused] = useState(false);
  const count = SHOWCASE_SCREENS.length;

  const go = useCallback(
    (next: number) => {
      setDir(next > index || (index === count - 1 && next === 0) ? 1 : -1);
      setIndex((next + count) % count);
    },
    [index, count]
  );

  useEffect(() => {
    if (paused) return;
    const t = setInterval(() => {
      setDir(1);
      setIndex((i) => (i + 1) % count);
    }, AUTOPLAY_MS);
    return () => clearInterval(t);
  }, [paused, count]);

  const active = SHOWCASE_SCREENS[index];

  return (
    <section className="overflow-hidden px-5 py-24">
      <div className="mx-auto max-w-6xl">
        <SectionHeading
          eyebrow="Screens"
          title="Every surface, beautifully simple"
          subtitle="Swipe through the app. Home, daily input, world, timeline, stats, and profile."
        />

        <div
          className="relative mt-14 flex flex-col items-center"
          onMouseEnter={() => setPaused(true)}
          onMouseLeave={() => setPaused(false)}
        >
          {/* glow */}
          <div className="pointer-events-none absolute top-10 h-72 w-72 rounded-full bg-[radial-gradient(circle,rgba(206,59,34,0.18),transparent_60%)] blur-2xl" />

          <div
            className="relative h-[640px] w-full max-w-sm select-none"
            onTouchStart={(e) => ((window as unknown as { _sx: number })._sx = e.touches[0].clientX)}
            onTouchEnd={(e) => {
              const sx = (window as unknown as { _sx: number })._sx ?? 0;
              const dx = e.changedTouches[0].clientX - sx;
              if (Math.abs(dx) > 40) go(index + (dx < 0 ? 1 : -1));
            }}
          >
            <AnimatePresence initial={false} custom={dir} mode="popLayout">
              <motion.div
                key={index}
                custom={dir}
                initial={{ opacity: 0, x: dir * 80, rotateY: dir * 8, scale: 0.92 }}
                animate={{ opacity: 1, x: 0, rotateY: 0, scale: 1 }}
                exit={{ opacity: 0, x: dir * -80, rotateY: dir * -8, scale: 0.92 }}
                transition={{ duration: 0.55, ease: [0.16, 1, 0.3, 1] }}
                className="absolute inset-0 grid place-items-center"
              >
                <PhoneFrame width={300}>
                  <AppScreen id={active.id} />
                </PhoneFrame>
              </motion.div>
            </AnimatePresence>
          </div>

          {/* controls */}
          <div className="mt-8 flex items-center gap-4">
            <button
              aria-label="Previous screen"
              onClick={() => go(index - 1)}
              className="grid h-11 w-11 place-items-center rounded-full bg-white ring-1 ring-[var(--color-line-strong)] transition-transform hover:scale-105"
            >
              <ChevronLeft size={20} />
            </button>

            <div className="text-center">
              <p className="text-lg font-bold tracking-tight">{active.title}</p>
              <p className="text-sm text-[var(--color-text-2)]">{active.caption}</p>
            </div>

            <button
              aria-label="Next screen"
              onClick={() => go(index + 1)}
              className="grid h-11 w-11 place-items-center rounded-full bg-white ring-1 ring-[var(--color-line-strong)] transition-transform hover:scale-105"
            >
              <ChevronRight size={20} />
            </button>
          </div>

          {/* dots */}
          <div className="mt-6 flex gap-2">
            {SHOWCASE_SCREENS.map((s, i) => (
              <button
                key={s.id}
                aria-label={`Go to ${s.title}`}
                onClick={() => go(i)}
                className={cn(
                  "h-2 rounded-full transition-all duration-300",
                  i === index ? "w-7 bg-[var(--color-brand)]" : "w-2 bg-[var(--color-line-strong)]"
                )}
              />
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
