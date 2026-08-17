"use client";

import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  Tooltip,
  BarChart,
  Bar,
  CartesianGrid,
  Legend,
} from "recharts";
import type { ScoorTrendPoint } from "@/types";

const RETENTION_DATA = [
  { week: "W1", d1: 82, d7: 61, d30: 44 },
  { week: "W2", d1: 79, d7: 63, d30: 42 },
  { week: "W3", d1: 85, d7: 65, d30: 47 },
  { week: "W4", d1: 88, d7: 68, d30: 51 },
  { week: "W5", d1: 84, d7: 66, d30: 49 },
  { week: "W6", d1: 90, d7: 71, d30: 55 },
  { week: "W7", d1: 87, d7: 69, d30: 52 },
  { week: "W8", d1: 92, d7: 74, d30: 58 },
];

interface Props {
  trend: ScoorTrendPoint[];
}

export function AnalyticsClient({ trend }: Props) {
  const chartData = trend.map((d) => ({
    ...d,
    label: new Date(d.date).toLocaleDateString("ko-KR", { month: "numeric", day: "numeric" }),
  }));

  return (
    <div className="flex-1 overflow-y-auto p-6 space-y-6">
      {/* KPI Overview */}
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "30일 활성 사용자", value: "142.4K", delta: "+8.2%", positive: true },
          { label: "평균 세션 길이", value: "3분 42초", delta: "+12s", positive: true },
          { label: "점수 기록 완료율", value: "91.4%", delta: "-0.8%", positive: false },
        ].map((m) => (
          <div key={m.label} className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5">
            <p className="text-xs text-[#52526c] uppercase tracking-wider mb-2">{m.label}</p>
            <p className="text-3xl font-bold text-[#f4f4f6] mb-1 tabular-nums">{m.value}</p>
            <span className={`text-xs font-medium ${m.positive ? "text-emerald-400" : "text-red-400"}`}>
              전월 대비 {m.delta}
            </span>
          </div>
        ))}
      </div>

      {/* Scoor Trend */}
      <div className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-sm font-semibold text-[#f4f4f6]">글로벌 스코어 추이 (30일)</h3>
          <div className="flex gap-2 text-xs">
            <span className="flex items-center gap-1.5 text-[#8b8ba4]">
              <span className="w-4 h-0.5 bg-[#f42525] inline-block" />
              플랫폼
            </span>
            <span className="flex items-center gap-1.5 text-[#8b8ba4]">
              <span className="w-4 h-0.5 bg-[#4f8ef7] inline-block opacity-60" />
              글로벌
            </span>
          </div>
        </div>
        <ResponsiveContainer width="100%" height={200}>
          <AreaChart data={chartData}>
            <defs>
              <linearGradient id="a1" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#f42525" stopOpacity={0.2} />
                <stop offset="100%" stopColor="#f42525" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="a2" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0%" stopColor="#4f8ef7" stopOpacity={0.1} />
                <stop offset="100%" stopColor="#4f8ef7" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
            <XAxis dataKey="label" tick={{ fill: "#52526c", fontSize: 10 }} tickLine={false} axisLine={false} interval={5} />
            <YAxis domain={[30, 100]} tick={{ fill: "#52526c", fontSize: 10 }} tickLine={false} axisLine={false} />
            <Tooltip
              contentStyle={{ background: "#1a1a2e", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, fontSize: 11 }}
              labelStyle={{ color: "#8b8ba4" }}
              itemStyle={{ color: "#f4f4f6" }}
            />
            <Area type="monotone" dataKey="globalAvg" name="글로벌" stroke="#4f8ef7" strokeWidth={1} strokeDasharray="4 4" fill="url(#a2)" dot={false} strokeOpacity={0.5} />
            <Area type="monotone" dataKey="avgScoor" name="플랫폼" stroke="#f42525" strokeWidth={2} fill="url(#a1)" dot={false} />
          </AreaChart>
        </ResponsiveContainer>
      </div>

      {/* Retention */}
      <div className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5">
        <h3 className="text-sm font-semibold text-[#f4f4f6] mb-4">사용자 리텐션 코호트 (%)</h3>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={RETENTION_DATA}>
            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.04)" />
            <XAxis dataKey="week" tick={{ fill: "#52526c", fontSize: 10 }} tickLine={false} axisLine={false} />
            <YAxis tick={{ fill: "#52526c", fontSize: 10 }} tickLine={false} axisLine={false} unit="%" />
            <Tooltip
              contentStyle={{ background: "#1a1a2e", border: "1px solid rgba(255,255,255,0.1)", borderRadius: 8, fontSize: 11 }}
              labelStyle={{ color: "#8b8ba4" }}
            />
            <Legend iconType="square" iconSize={8} wrapperStyle={{ fontSize: 11, color: "#8b8ba4" }} />
            <Bar dataKey="d1" name="D1" fill="#f42525" opacity={0.8} radius={[3, 3, 0, 0]} />
            <Bar dataKey="d7" name="D7" fill="#4f8ef7" opacity={0.8} radius={[3, 3, 0, 0]} />
            <Bar dataKey="d30" name="D30" fill="#22c55e" opacity={0.8} radius={[3, 3, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
