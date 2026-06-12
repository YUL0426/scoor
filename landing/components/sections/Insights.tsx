"use client";

import { motion } from "framer-motion";
import { Flame, TrendingUp, CalendarDays, Target } from "lucide-react";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/motion/Reveal";
import { ScoreCounter } from "@/components/motion/ScoreCounter";
import { MONTHLY_TREND } from "@/lib/data";
import { scoreColor } from "@/lib/utils";

function TrendChart() {
  const w = 520;
  const h = 180;
  const max = 100;
  const pts = MONTHLY_TREND.map((v, i) => {
    const x = (i / (MONTHLY_TREND.length - 1)) * w;
    const y = h - (v / max) * h;
    return [x, y] as const;
  });
  const line = pts.map(([x, y], i) => `${i === 0 ? "M" : "L"}${x},${y}`).join(" ");
  const area = `${line} L${w},${h} L0,${h} Z`;

  return (
    <svg viewBox={`0 0 ${w} ${h}`} className="h-44 w-full" preserveAspectRatio="none">
      <defs>
        <linearGradient id="trendFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="var(--color-brand)" stopOpacity="0.28" />
          <stop offset="100%" stopColor="var(--color-brand)" stopOpacity="0" />
        </linearGradient>
      </defs>
      <motion.path
        d={area}
        fill="url(#trendFill)"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 1, delay: 0.4 }}
      />
      <motion.path
        d={line}
        fill="none"
        stroke="var(--color-brand)"
        strokeWidth={3}
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={{ pathLength: 0 }}
        whileInView={{ pathLength: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 1.4, ease: [0.16, 1, 0.3, 1] }}
      />
      {pts.map(([x, y], i) => (
        <motion.circle
          key={i}
          cx={x}
          cy={y}
          r={3.5}
          fill="#fff"
          stroke="var(--color-brand)"
          strokeWidth={2}
          initial={{ scale: 0 }}
          whileInView={{ scale: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.6 + i * 0.05 }}
        />
      ))}
    </svg>
  );
}

const TILES = [
  { Icon: Flame, label: "Day streak", value: 48, color: "#f5a623" },
  { Icon: TrendingUp, label: "Weekly avg", value: 76, color: scoreColor(76) },
  { Icon: Target, label: "Best score", value: 95, color: scoreColor(95) },
  { Icon: CalendarDays, label: "This month", value: 31, color: "#4f8ef7" },
];

export function Insights() {
  return (
    <section id="insights" className="px-5 py-24">
      <div className="mx-auto max-w-6xl">
        <SectionHeading
          eyebrow="Personal insights"
          title="Your life, in numbers"
          subtitle="Daily, weekly, monthly, yearly. Scoor turns every score into trends, streaks, and patterns you'll actually want to check."
        />

        <div className="mt-14 grid gap-6 lg:grid-cols-[1.3fr_1fr]">
          <Reveal className="rounded-[var(--radius-card)] bg-white p-6 ring-1 ring-[var(--color-line)]">
            <div className="flex items-baseline justify-between">
              <div>
                <p className="text-sm font-medium text-[var(--color-text-2)]">Average score</p>
                <p className="text-4xl font-bold">
                  <ScoreCounter to={78} />
                </p>
              </div>
              <span className="rounded-full bg-[var(--color-score-100)]/12 px-3 py-1 text-sm font-semibold text-[#1fa968]">
                ▲ 12% this month
              </span>
            </div>
            <div className="mt-4">
              <TrendChart />
            </div>
          </Reveal>

          <div className="grid grid-cols-2 gap-4">
            {TILES.map((t, i) => (
              <Reveal key={t.label} index={i}>
                <div className="h-full rounded-3xl bg-white p-5 ring-1 ring-[var(--color-line)] transition-transform duration-300 hover:-translate-y-1">
                  <t.Icon size={22} style={{ color: t.color }} />
                  <p className="mt-4 text-3xl font-bold" style={{ color: t.color }}>
                    <ScoreCounter to={t.value} />
                  </p>
                  <p className="text-sm text-[var(--color-text-2)]">{t.label}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
