"use client";

import { TrendingUp, TrendingDown, Minus } from "lucide-react";
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  Tooltip,
} from "recharts";
import { cn, formatDelta } from "@/lib/utils";
import type { KPIMetric } from "@/types";

interface KPICardProps {
  metric: KPIMetric;
  accentColor?: string;
}

const TREND_CONFIG = {
  up: {
    icon: TrendingUp,
    color: "text-emerald-400",
    bg: "bg-emerald-500/10 border-emerald-500/20",
  },
  down: {
    icon: TrendingDown,
    color: "text-red-400",
    bg: "bg-red-500/10 border-red-500/20",
  },
  neutral: {
    icon: Minus,
    color: "text-[#8b8ba4]",
    bg: "bg-white/6 border-white/10",
  },
};

export function KPICard({ metric, accentColor = "#f42525" }: KPICardProps) {
  const trendCfg = TREND_CONFIG[metric.trend];
  const TrendIcon = trendCfg.icon;

  const chartData = metric.sparkline.map((v, i) => ({ i, v }));

  return (
    <div className="relative bg-[#0d0d1f] border border-white/6 rounded-xl p-5 overflow-hidden hover:border-white/10 transition-all duration-200 group">
      {/* Background gradient */}
      <div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"
        style={{
          background: `radial-gradient(ellipse at top right, ${accentColor}08 0%, transparent 70%)`,
        }}
      />

      {/* Label */}
      <p className="text-xs font-medium text-[#52526c] uppercase tracking-wider mb-3">
        {metric.label}
      </p>

      {/* Value */}
      <p className="text-3xl font-bold text-[#f4f4f6] tracking-tight mb-3 tabular-nums">
        {metric.formatted}
      </p>

      {/* Trend badge */}
      <div
        className={cn(
          "inline-flex items-center gap-1 px-2 py-1 rounded-full border text-xs font-medium mb-4",
          trendCfg.bg,
          trendCfg.color
        )}
      >
        <TrendIcon className="h-3 w-3" />
        <span>{formatDelta(metric.delta)}</span>
        <span className="text-[10px] opacity-70">{metric.deltaLabel}</span>
      </div>

      {/* Sparkline */}
      <div className="h-9 -mx-1">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id={`grad-${metric.label}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor={accentColor} stopOpacity={0.25} />
                <stop offset="100%" stopColor={accentColor} stopOpacity={0} />
              </linearGradient>
            </defs>
            <Area
              type="monotone"
              dataKey="v"
              stroke={accentColor}
              strokeWidth={1.5}
              fill={`url(#grad-${metric.label})`}
              dot={false}
              activeDot={false}
            />
            <Tooltip content={() => null} />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
