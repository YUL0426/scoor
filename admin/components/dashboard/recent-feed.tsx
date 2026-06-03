"use client";

import { Rss, Heart, MessageCircle } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { formatRelativeTime, scoorToColor } from "@/lib/utils";
import type { FeedEntry } from "@/types";

function FeedRow({ entry }: { entry: FeedEntry }) {
  const color = entry.scoorValue !== null ? scoorToColor(entry.scoorValue) : "#8b8ba4";
  const initial = entry.username[0]?.toUpperCase();

  return (
    <div className="flex items-start gap-3 py-2.5 border-b border-white/4 last:border-0 hover:bg-white/2 rounded-lg px-2 -mx-2 transition-colors">
      {/* Avatar */}
      <div
        className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 text-white flex-none"
        style={{ background: `${color}33`, color }}
      >
        {initial}
      </div>

      {/* Content */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5 mb-0.5">
          <span className="text-xs font-medium text-[#f4f4f6]">{entry.username}</span>
          <span className="text-[10px] text-[#52526c]">{entry.countryCode}</span>
          {entry.scoorValue !== null && (
            <span
              className="ml-auto text-sm font-bold tabular-nums flex-shrink-0"
              style={{ color }}
            >
              {entry.scoorValue}
            </span>
          )}
        </div>
        {entry.reason && (
          <p className="text-[11px] text-[#8b8ba4] truncate">{entry.reason}</p>
        )}
        {entry.agendaTitle && (
          <p className="text-[10px] text-[#52526c] mt-0.5">↳ {entry.agendaTitle}</p>
        )}
        <div className="flex items-center gap-3 mt-1.5">
          <span className="flex items-center gap-1 text-[10px] text-[#52526c]">
            <Heart className="h-2.5 w-2.5" />
            {entry.likeCount}
          </span>
          <span className="flex items-center gap-1 text-[10px] text-[#52526c]">
            <MessageCircle className="h-2.5 w-2.5" />
            {entry.commentCount}
          </span>
          <span className="text-[10px] text-[#52526c] ml-auto">
            {formatRelativeTime(entry.createdAt)}
          </span>
        </div>
      </div>
    </div>
  );
}

interface RecentFeedProps {
  entries: FeedEntry[];
}

export function RecentFeed({ entries }: RecentFeedProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Rss className="h-4 w-4 text-[#06b6d4]" />
          Live Feed
        </CardTitle>
        <div className="flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
          <span className="text-[10px] text-emerald-400">live</span>
        </div>
      </CardHeader>
      <CardContent className="py-2">
        {entries.map((entry) => (
          <FeedRow key={entry.id} entry={entry} />
        ))}
      </CardContent>
    </Card>
  );
}
