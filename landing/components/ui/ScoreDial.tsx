"use client";

import { motion, useInView } from "framer-motion";
import { useRef } from "react";
import { scoreColor } from "@/lib/utils";

/**
 * Circular 0–100 score gauge. The arc draws in and the color tracks the
 * sentiment ramp. Used inside the daily-score app screen and the hero.
 */
export function ScoreDial({
  score,
  size = 168,
  stroke = 12,
  showValue = true,
}: {
  score: number;
  size?: number;
  stroke?: number;
  showValue?: boolean;
}) {
  const ref = useRef<SVGSVGElement>(null);
  const inView = useInView(ref, { once: true, margin: "-10% 0px" });
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const color = scoreColor(score);
  const pct = Math.max(0, Math.min(100, score)) / 100;

  return (
    <div className="relative grid place-items-center" style={{ width: size, height: size }}>
      <svg ref={ref} width={size} height={size} className="-rotate-90">
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke="rgba(20,20,26,0.07)"
          strokeWidth={stroke}
        />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          initial={{ strokeDashoffset: c }}
          animate={inView ? { strokeDashoffset: c - c * pct } : {}}
          transition={{ duration: 1.4, ease: [0.16, 1, 0.3, 1] }}
          style={{ filter: `drop-shadow(0 2px 8px ${color}55)` }}
        />
      </svg>
      {showValue && (
        <div className="absolute inset-0 grid place-items-center rotate-0">
          <div
            className="font-bold leading-none tracking-tight"
            style={{ fontSize: size * 0.34, color }}
          >
            {Math.round(score)}
          </div>
        </div>
      )}
    </div>
  );
}
