"use client";

import { TrendingUp, TrendingDown, Minus } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { cn, scoorToColor, formatDelta } from "@/lib/utils";
import type { CountryPulse } from "@/types";

const FLAG_BASE = "https://flagcdn.com/24x18";

function CountryRow({ pulse }: { pulse: CountryPulse }) {
  const color = scoorToColor(pulse.avgScoor);
  const TrendIcon =
    pulse.trend === "up" ? TrendingUp : pulse.trend === "down" ? TrendingDown : Minus;
  const trendColor =
    pulse.trend === "up"
      ? "text-emerald-400"
      : pulse.trend === "down"
      ? "text-red-400"
      : "text-[#8b8ba4]";

  return (
    <div className="flex items-center gap-3 py-2.5 border-b border-white/4 last:border-0 hover:bg-white/2 rounded-lg px-2 -mx-2 transition-colors group">
      {/* Flag */}
      <div className="w-6 h-4 rounded-sm overflow-hidden flex-shrink-0 bg-white/10">
        <img
          src={`${FLAG_BASE}/${pulse.countryCode.toLowerCase()}.png`}
          alt={pulse.country}
          className="w-full h-full object-cover"
          onError={(e) => {
            (e.target as HTMLImageElement).style.display = "none";
          }}
        />
      </div>

      {/* Country info */}
      <div className="flex-1 min-w-0">
        <p className="text-xs font-medium text-[#f4f4f6] truncate">{pulse.country}</p>
        {pulse.topAgendaTitle && (
          <p className="text-[10px] text-[#52526c] truncate">{pulse.topAgendaTitle}</p>
        )}
      </div>

      {/* Participants */}
      <span className="text-[10px] text-[#52526c] tabular-nums hidden group-hover:inline">
        {pulse.participantCount.toLocaleString()}
      </span>

      {/* Trend */}
      <div className={cn("flex items-center gap-0.5 text-[10px]", trendColor)}>
        <TrendIcon className="h-3 w-3" />
        <span className="tabular-nums">{formatDelta(pulse.delta)}</span>
      </div>

      {/* Score */}
      <div
        className="flex items-center justify-center w-10 h-6 rounded-md text-xs font-bold tabular-nums text-white flex-shrink-0"
        style={{ background: `${color}22`, color, borderWidth: 1, borderColor: `${color}33`, borderStyle: "solid" }}
      >
        {pulse.avgScoor.toFixed(0)}
      </div>
    </div>
  );
}

interface WorldPulseProps {
  data: CountryPulse[];
}

export function WorldPulse({ data }: WorldPulseProps) {
  const sorted = [...data].sort((a, b) => b.avgScoor - a.avgScoor);

  return (
    <Card>
      <CardHeader>
        <CardTitle>월드 펄스</CardTitle>
        <span className="text-xs text-[#52526c]">Live emotional climate</span>
      </CardHeader>
      <CardContent className="py-2">
        <div className="space-y-0">
          {sorted.map((pulse) => (
            <CountryRow key={pulse.countryCode} pulse={pulse} />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
