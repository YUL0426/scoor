import { Header } from "@/components/admin/header";
import { Badge } from "@/components/ui/badge";
import { mockAgendas } from "@/lib/mock/agendas";
import { formatRelativeTime, scoorToColor, formatNumber, statusLabel } from "@/lib/utils";
import { Globe, Flame, Activity, Users } from "lucide-react";
import type { AgendaCategory } from "@/types";

const CATEGORY_COLORS: Record<AgendaCategory, string> = {
  politics: "#4f8ef7",
  culture: "#a855f7",
  economy: "#f59e0b",
  environment: "#22c55e",
  sports: "#f42525",
  technology: "#06b6d4",
  health: "#fb7185",
};

export default function AgendaPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="월드 아젠다" subtitle="글로벌 감정 이벤트 관리" />
      <div className="flex-1 overflow-y-auto p-6">
        {/* Stats */}
        <div className="grid grid-cols-4 gap-4 mb-6">
          {[
            { label: "진행 중", value: "18", color: "#22c55e" },
            { label: "인기", value: "4", color: "#f42525" },
            { label: "전체 반응", value: "142K", color: "#4f8ef7" },
            { label: "평균 참여", value: "8.4K", color: "#a855f7" },
          ].map((s) => (
            <div key={s.label} className="bg-[#0d0d1f] border border-white/6 rounded-xl px-5 py-4">
              <p className="text-xs text-[#52526c] uppercase tracking-wider mb-1">{s.label}</p>
              <p className="text-2xl font-bold tabular-nums" style={{ color: s.color }}>{s.value}</p>
            </div>
          ))}
        </div>

        {/* Agenda grid */}
        <div className="grid grid-cols-1 xl:grid-cols-2 gap-4">
          {mockAgendas.map((agenda) => {
            const color = scoorToColor(agenda.avgScoor);
            const catColor = CATEGORY_COLORS[agenda.category];
            const isHot = agenda.trendDelta > 10;

            return (
              <div
                key={agenda.id}
                className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5 hover:border-white/12 transition-all duration-150 group cursor-pointer"
              >
                {/* Header */}
                <div className="flex items-start justify-between gap-3 mb-3">
                  <div className="flex items-center gap-2 flex-1 min-w-0">
                    <div
                      className="w-2 h-2 rounded-full flex-shrink-0"
                      style={{ background: catColor }}
                    />
                    <p className="text-sm font-semibold text-[#f4f4f6] truncate leading-snug">
                      {agenda.title}
                    </p>
                  </div>
                  <div className="flex items-center gap-1.5 flex-shrink-0">
                    {isHot && <Flame className="h-4 w-4 text-[#f42525]" />}
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
                      {statusLabel(agenda.status)}
                    </Badge>
                  </div>
                </div>

                <p className="text-xs text-[#8b8ba4] mb-4 line-clamp-2">{agenda.description}</p>

                {/* Tags */}
                <div className="flex flex-wrap gap-1 mb-4">
                  <span
                    className="px-2 py-0.5 rounded-full text-[10px] font-medium border"
                    style={{ color: catColor, borderColor: `${catColor}30`, background: `${catColor}10` }}
                  >
                    {agenda.category}
                  </span>
                  {agenda.tags.slice(0, 3).map((t) => (
                    <span key={t} className="px-2 py-0.5 rounded-full text-[10px] text-[#52526c] bg-white/4 border border-white/6">
                      {t}
                    </span>
                  ))}
                </div>

                {/* Stats row */}
                <div className="flex items-center gap-4 pt-3 border-t border-white/4">
                  <div className="flex items-center gap-1.5 text-xs text-[#8b8ba4]">
                    <Users className="h-3 w-3" />
                    <span className="tabular-nums">{formatNumber(agenda.participantCount)}</span>
                  </div>
                  <div className="flex items-center gap-1.5 text-xs text-[#8b8ba4]">
                    <Activity className="h-3 w-3" />
                    <span className="tabular-nums">{formatNumber(agenda.reactionCount)}</span>
                  </div>
                  <div className="ml-auto flex items-center gap-2">
                    <Globe className="h-3 w-3 text-[#52526c]" />
                    <span className="text-[10px] text-[#52526c]">{formatRelativeTime(agenda.createdAt)}</span>
                    <span
                      className="text-sm font-bold tabular-nums"
                      style={{ color }}
                    >
                      {agenda.avgScoor.toFixed(0)}
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
