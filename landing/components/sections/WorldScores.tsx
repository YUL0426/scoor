"use client";

import { motion } from "framer-motion";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/motion/Reveal";
import { WORLD_TOPICS } from "@/lib/data";
import { scoreColor, formatCompact } from "@/lib/utils";

/** A deterministic 12×8 sentiment heat grid derived from the topic scores. */
const GRID = Array.from({ length: 8 * 14 }, (_, i) => {
  const base = WORLD_TOPICS[i % WORLD_TOPICS.length].score;
  const wobble = ((i * 37) % 23) - 11;
  return Math.max(4, Math.min(100, base + wobble));
});

export function WorldScores() {
  return (
    <section id="world" className="px-5 py-24">
      <div className="mx-auto max-w-6xl">
        <SectionHeading
          eyebrow="World scores"
          title="See how the world feels"
          subtitle="Apple, Tesla, AI, climate, politics, sports — every topic gets a live public score from millions of people."
        />

        <div className="mt-14 grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          {/* Heatmap */}
          <Reveal className="rounded-[var(--radius-card)] bg-[var(--color-ink)] p-6 text-white">
            <div className="flex items-center justify-between">
              <p className="text-sm font-semibold">Global sentiment</p>
              <span className="flex items-center gap-1.5 text-xs text-white/60">
                <span className="h-2 w-2 animate-pulse rounded-full bg-[var(--color-score-100)]" />
                live
              </span>
            </div>
            <div className="mt-5 grid grid-cols-[repeat(14,minmax(0,1fr))] gap-1.5">
              {GRID.map((v, i) => (
                <motion.div
                  key={i}
                  initial={{ opacity: 0, scale: 0.4 }}
                  whileInView={{ opacity: 0.4 + (v / 100) * 0.6, scale: 1 }}
                  viewport={{ once: true }}
                  transition={{ delay: (i % 14) * 0.015 + Math.floor(i / 14) * 0.02, duration: 0.4 }}
                  className="aspect-square rounded-[4px]"
                  style={{ background: scoreColor(v) }}
                />
              ))}
            </div>
            <div className="mt-5 flex items-center gap-2 text-[11px] text-white/55">
              <span>Negative</span>
              <div className="h-2 flex-1 rounded-full" style={{ background: "linear-gradient(90deg,#e23a2e,#f5a623,#1fc77b)" }} />
              <span>Positive</span>
            </div>
          </Reveal>

          {/* Trending list */}
          <Reveal index={1} className="rounded-[var(--radius-card)] bg-white p-3 ring-1 ring-[var(--color-line)]">
            {WORLD_TOPICS.slice(0, 6).map((t) => (
              <div key={t.id} className="flex items-center gap-3 rounded-2xl px-3 py-2.5 transition-colors hover:bg-[var(--color-canvas)]">
                <div className="grid h-10 w-10 place-items-center rounded-xl text-sm font-bold text-white" style={{ background: scoreColor(t.score) }}>
                  {t.score}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-semibold">{t.name}</p>
                  <p className="text-[11px] text-[var(--color-text-3)]">{formatCompact(t.votes)} scores</p>
                </div>
                <span className={`text-xs font-semibold ${t.delta >= 0 ? "text-[#1fa968]" : "text-[#e23a2e]"}`}>
                  {t.delta >= 0 ? "▲" : "▼"} {Math.abs(t.delta)}%
                </span>
              </div>
            ))}
          </Reveal>
        </div>
      </div>
    </section>
  );
}
