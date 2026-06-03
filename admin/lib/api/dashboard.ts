import type { DashboardMetrics, ScoorTrendPoint, CountryPulse } from "@/types";
import { mockDashboardMetrics, mockScoorTrend, mockWorldPulse } from "@/lib/mock/metrics";

// In production, replace mock imports with actual fetch calls.
// The function signatures stay the same — only the body changes.

export async function getDashboardMetrics(): Promise<DashboardMetrics> {
  await new Promise((r) => setTimeout(r, 120));
  return mockDashboardMetrics;
}

export async function getScoorTrend(days = 30): Promise<ScoorTrendPoint[]> {
  await new Promise((r) => setTimeout(r, 80));
  return mockScoorTrend.slice(-days);
}

export async function getWorldPulse(): Promise<CountryPulse[]> {
  await new Promise((r) => setTimeout(r, 100));
  return mockWorldPulse;
}
