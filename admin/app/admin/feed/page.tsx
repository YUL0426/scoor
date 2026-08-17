import { Header } from "@/components/admin/header";
import { mockFeedEntries } from "@/lib/mock/feed";
import { formatRelativeTime, scoorToColor } from "@/lib/utils";
import { Heart, MessageCircle, Eye, EyeOff } from "lucide-react";
import { Badge } from "@/components/ui/badge";

export default function FeedPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="피드" subtitle="실시간 소셜 활동 스트림" />
      <div className="flex-1 overflow-y-auto p-6">
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-2">
            <span className="w-2 h-2 bg-emerald-400 rounded-full animate-pulse" />
            <span className="text-sm text-emerald-400 font-medium">실시간 피드</span>
          </div>
          <div className="flex items-center gap-2">
            {["전체", "점수", "반응", "댓글"].map((f) => (
              <button
                key={f}
                className="px-3 py-1.5 rounded-lg text-xs font-medium border border-white/8 text-[#8b8ba4] hover:border-white/16 hover:text-[#f4f4f6] transition-colors first:bg-white/6 first:text-[#f4f4f6] first:border-white/12"
              >
                {f}
              </button>
            ))}
          </div>
        </div>

        <div className="space-y-3 max-w-2xl">
          {mockFeedEntries.map((entry) => {
            const color = entry.scoorValue !== null ? scoorToColor(entry.scoorValue) : "#8b8ba4";
            const initial = entry.username[0]?.toUpperCase();

            return (
              <div
                key={entry.id}
                className="bg-[#0d0d1f] border border-white/6 rounded-xl p-4 hover:border-white/10 transition-all"
              >
                <div className="flex items-start gap-3">
                  <div
                    className="w-9 h-9 rounded-full flex items-center justify-center text-sm font-bold flex-shrink-0 text-white"
                    style={{ background: `${color}33`, color }}
                  >
                    {initial}
                  </div>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1.5">
                      <span className="text-sm font-medium text-[#f4f4f6]">{entry.username}</span>
                      <span className="text-xs text-[#52526c]">{entry.country}</span>
                      <Badge variant={entry.type === "agenda_reaction" ? "info" : "neutral"}>
                        {entry.type === "agenda_reaction" ? "반응" : "점수"}
                      </Badge>
                      <span className="ml-auto text-xs text-[#52526c]">
                        {formatRelativeTime(entry.createdAt)}
                      </span>
                    </div>

                    {entry.reason && (
                      <p className="text-sm text-[#8b8ba4] mb-2">{entry.reason}</p>
                    )}

                    {entry.agendaTitle && (
                      <p className="text-xs text-[#52526c] mb-2">↳ {entry.agendaTitle}</p>
                    )}

                    <div className="flex items-center gap-4">
                      <span className="flex items-center gap-1.5 text-xs text-[#52526c]">
                        <Heart className="h-3.5 w-3.5" />
                        {entry.likeCount}
                      </span>
                      <span className="flex items-center gap-1.5 text-xs text-[#52526c]">
                        <MessageCircle className="h-3.5 w-3.5" />
                        {entry.commentCount}
                      </span>
                      <div className="ml-auto flex items-center gap-2">
                        <button className="p-1.5 rounded-md hover:bg-white/5 text-[#52526c] hover:text-[#8b8ba4] transition-colors">
                          {entry.isVisible ? (
                            <Eye className="h-3.5 w-3.5" />
                          ) : (
                            <EyeOff className="h-3.5 w-3.5" />
                          )}
                        </button>
                      </div>
                    </div>
                  </div>

                  {entry.scoorValue !== null && (
                    <div
                      className="flex-shrink-0 flex items-center justify-center w-12 h-12 rounded-xl font-black text-lg tabular-nums"
                      style={{ background: `${color}18`, color, border: `1px solid ${color}30` }}
                    >
                      {entry.scoorValue}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
