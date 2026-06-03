"use client";

import { Globe, Flame, Activity } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatRelativeTime, scoorToColor, formatNumber } from "@/lib/utils";
import type { Agenda, AgendaCategory } from "@/types";

const CATEGORY_LABELS: Record<AgendaCategory, string> = {
  politics: "Politics",
  culture: "Culture",
  economy: "Economy",
  environment: "Environment",
  sports: "Sports",
  technology: "Tech",
  health: "Health",
};

function AgendaRow({ agenda }: { agenda: Agenda }) {
  const color = scoorToColor(agenda.avgScoor);
  const isHot = agenda.trendDelta > 10;

  return (
    <div className="flex items-start gap-3 py-3 border-b border-white/4 last:border-0 hover:bg-white/2 rounded-lg px-2 -mx-2 transition-colors cursor-pointer group">
      {/* Score indicator */}
      <div
        className="flex-shrink-0 w-1 h-full min-h-10 rounded-full mt-0.5"
        style={{ background: color }}
      />

      <div className="flex-1 min-w-0">
        <div className="flex items-start justify-between gap-2 mb-1">
          <p className="text-xs font-medium text-[#f4f4f6] leading-snug truncate">{agenda.title}</p>
          {isHot && <Flame className="h-3.5 w-3.5 text-[#f42525] flex-shrink-0" />}
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <Badge
            variant={
              agenda.status === "trending"
                ? "trending"
                : agenda.status === "active"
                ? "success"
                : "neutral"
            }
            dot
          >
            {agenda.status}
          </Badge>
          <span className="text-[10px] text-[#52526c]">
            {CATEGORY_LABELS[agenda.category]}
          </span>
          <span className="text-[10px] text-[#52526c] flex items-center gap-1">
            <Activity className="h-2.5 w-2.5" />
            {formatNumber(agenda.participantCount)}
          </span>
        </div>
      </div>

      {/* Avg scoor */}
      <div className="flex flex-col items-end flex-shrink-0">
        <span
          className="text-sm font-bold tabular-nums"
          style={{ color }}
        >
          {agenda.avgScoor.toFixed(0)}
        </span>
        <span className="text-[10px] text-[#52526c]">
          {formatRelativeTime(agenda.createdAt)}
        </span>
      </div>
    </div>
  );
}

interface RecentAgendasProps {
  agendas: Agenda[];
}

export function RecentAgendas({ agendas }: RecentAgendasProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Globe className="h-4 w-4 text-[#4f8ef7]" />
          Active Agendas
        </CardTitle>
        <span className="text-xs text-[#52526c]">{agendas.length} running</span>
      </CardHeader>
      <CardContent className="py-2">
        {agendas.map((agenda) => (
          <AgendaRow key={agenda.id} agenda={agenda} />
        ))}
      </CardContent>
    </Card>
  );
}
