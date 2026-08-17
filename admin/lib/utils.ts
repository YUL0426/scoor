import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";
import type { EmotionLevel } from "@/types";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return n.toLocaleString();
}

export function formatScoor(n: number): string {
  return n.toFixed(1);
}

export function formatDelta(delta: number, suffix = "%"): string {
  const sign = delta >= 0 ? "+" : "";
  return `${sign}${delta.toFixed(1)}${suffix}`;
}

export function formatRelativeTime(dateStr: string): string {
  const date = new Date(dateStr);
  const now = new Date();
  const diff = Math.floor((now.getTime() - date.getTime()) / 1000);

  if (diff < 60) return `${diff}초 전`;
  if (diff < 3600) return `${Math.floor(diff / 60)}분 전`;
  if (diff < 86400) return `${Math.floor(diff / 3600)}시간 전`;
  if (diff < 604800) return `${Math.floor(diff / 86400)}일 전`;
  return date.toLocaleDateString("ko-KR", { month: "long", day: "numeric" });
}

export function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("ko-KR", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}

export function emotionFromScoor(score: number): EmotionLevel {
  if (score < 20) return "very_low";
  if (score < 40) return "low";
  if (score < 60) return "neutral";
  if (score < 80) return "high";
  return "very_high";
}

export function emotionColor(level: EmotionLevel): string {
  const map: Record<EmotionLevel, string> = {
    very_low: "#f42525",
    low: "#fb7185",
    neutral: "#f59e0b",
    high: "#22c55e",
    very_high: "#4f8ef7",
  };
  return map[level];
}

export function scoorToColor(score: number): string {
  return emotionColor(emotionFromScoor(score));
}

export function scoorToGradient(score: number): string {
  const level = emotionFromScoor(score);
  const gradients: Record<EmotionLevel, string> = {
    very_low: "from-red-600/20 to-red-900/5",
    low: "from-rose-500/20 to-rose-900/5",
    neutral: "from-amber-500/20 to-amber-900/5",
    high: "from-emerald-500/20 to-emerald-900/5",
    very_high: "from-blue-500/20 to-blue-900/5",
  };
  return gradients[level];
}

export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export function generateSparkline(base: number, points = 8): number[] {
  return Array.from({ length: points }, () =>
    Math.max(0, Math.min(100, base + (Math.random() - 0.5) * 20))
  );
}

/// 화면 표시용 상태 라벨. 키는 목업/DB의 원시 값이므로 바꾸지 않는다 — 번역은
/// 표시 계층에서만 한다. 모르는 값은 그대로 보여준다(빈 배지보다 낫다).
const STATUS_LABELS: Record<string, string> = {
  active: "활성",
  suspended: "정지",
  banned: "차단",
  deleted: "삭제됨",
  pending: "대기",
  reviewed: "검토됨",
  resolved: "처리 완료",
  dismissed: "기각",
  trending: "인기",
  expired: "만료",
  scheduled: "예약",
  draft: "초안",
  live: "공개",
  closed: "마감",
};

export function statusLabel(raw: string): string {
  return STATUS_LABELS[raw] ?? raw;
}
