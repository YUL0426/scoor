import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatCompact(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, "")}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1).replace(/\.0$/, "")}K`;
  return n.toLocaleString();
}

/** Stop value (0–1) along the 5-stop score ramp for a 0–100 score. */
function lerpColor(a: number[], b: number[], t: number) {
  return a.map((c, i) => Math.round(c + (b[i] - c) * t));
}

const SCORE_STOPS: [number, number[]][] = [
  [0, [226, 58, 46]], // #e23a2e
  [25, [240, 87, 60]], // #f0573c
  [50, [245, 166, 35]], // #f5a623
  [75, [122, 199, 79]], // #7ac74f
  [100, [31, 199, 123]], // #1fc77b
];

/** Smooth color for any 0–100 score, interpolated across the sentiment ramp. */
export function scoreColor(score: number): string {
  const s = Math.max(0, Math.min(100, score));
  for (let i = 0; i < SCORE_STOPS.length - 1; i++) {
    const [lo, loC] = SCORE_STOPS[i];
    const [hi, hiC] = SCORE_STOPS[i + 1];
    if (s <= hi) {
      const t = (s - lo) / (hi - lo);
      const [r, g, b] = lerpColor(loC, hiC, t);
      return `rgb(${r}, ${g}, ${b})`;
    }
  }
  return "rgb(31, 199, 123)";
}

export function scoreLabel(score: number): string {
  if (score < 20) return "Rough";
  if (score < 40) return "Meh";
  if (score < 60) return "Okay";
  if (score < 80) return "Good";
  if (score < 92) return "Great";
  return "Incredible";
}

export function scoreEmoji(score: number): string {
  if (score < 20) return "😣";
  if (score < 40) return "😕";
  if (score < 60) return "😐";
  if (score < 80) return "🙂";
  if (score < 92) return "😄";
  return "🤩";
}
