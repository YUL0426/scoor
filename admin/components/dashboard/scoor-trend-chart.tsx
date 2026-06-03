"use client";

import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  ReferenceLine,
} from "recharts";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import type { ScoorTrendPoint } from "@/types";

interface CustomTooltipProps {
  active?: boolean;
  payload?: Array<{ value: number; name: string; color: string }>;
  label?: string;
}

function CustomTooltip({ active, payload, label }: CustomTooltipProps) {
  if (!active || !payload?.length) return null;
  return (
    <div className="bg-[#1a1a2e] border border-white/10 rounded-lg px-3 py-2 shadow-xl text-xs">
      <p className="text-[#8b8ba4] mb-1">{label}</p>
      {payload.map((p) => (
        <div key={p.name} className="flex items-center gap-2">
          <span className="w-1.5 h-1.5 rounded-full" style={{ background: p.color }} />
          <span className="text-[#8b8ba4]">{p.name}:</span>
          <span className="text-[#f4f4f6] font-semibold tabular-nums">{p.value.toFixed(1)}</span>
        </div>
      ))}
    </div>
  );
}

interface ScoorTrendChartProps {
  data: ScoorTrendPoint[];
}

export function ScoorTrendChart({ data }: ScoorTrendChartProps) {
  const shortDates = data.map((d) => ({
    ...d,
    label: new Date(d.date).toLocaleDateString("en-US", { month: "short", day: "numeric" }),
  }));

  const visible = shortDates.filter((_, i) => i % 5 === 0 || i === shortDates.length - 1);
  const visibleLabels = new Set(visible.map((d) => d.label));

  return (
    <Card className="col-span-2">
      <CardHeader>
        <CardTitle>Global Scoor Pulse — 30d</CardTitle>
        <div className="flex items-center gap-4 text-xs">
          <span className="flex items-center gap-1.5 text-[#8b8ba4]">
            <span className="w-6 h-0.5 bg-[#f42525] inline-block rounded" />
            Platform Avg
          </span>
          <span className="flex items-center gap-1.5 text-[#8b8ba4]">
            <span className="w-6 h-0.5 bg-[#4f8ef7] inline-block rounded opacity-60" style={{ borderStyle: "dashed" }} />
            Global Baseline
          </span>
        </div>
      </CardHeader>
      <CardContent className="pt-4 pb-2">
        <ResponsiveContainer width="100%" height={180}>
          <AreaChart data={shortDates} margin={{ top: 4, right: 4, left: -20, bottom: 0 }}>
            <defs>
              <linearGradient id="scoorGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#f42525" stopOpacity={0.2} />
                <stop offset="100%" stopColor="#f42525" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="globalGrad" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#4f8ef7" stopOpacity={0.1} />
                <stop offset="100%" stopColor="#4f8ef7" stopOpacity={0} />
              </linearGradient>
            </defs>
            <XAxis
              dataKey="label"
              tick={{ fill: "#52526c", fontSize: 10 }}
              tickLine={false}
              axisLine={false}
              interval="preserveStartEnd"
              tickFormatter={(val) => (visibleLabels.has(val) ? val : "")}
            />
            <YAxis
              domain={[30, 100]}
              tick={{ fill: "#52526c", fontSize: 10 }}
              tickLine={false}
              axisLine={false}
            />
            <Tooltip content={<CustomTooltip />} />
            <ReferenceLine y={50} stroke="rgba(255,255,255,0.05)" strokeDasharray="4 4" />
            <Area
              type="monotone"
              dataKey="globalAvg"
              name="Global"
              stroke="#4f8ef7"
              strokeWidth={1}
              strokeDasharray="4 4"
              fill="url(#globalGrad)"
              dot={false}
              strokeOpacity={0.5}
            />
            <Area
              type="monotone"
              dataKey="avgScoor"
              name="Platform"
              stroke="#f42525"
              strokeWidth={2}
              fill="url(#scoorGrad)"
              dot={false}
              activeDot={{ r: 4, fill: "#f42525", strokeWidth: 0 }}
            />
          </AreaChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
