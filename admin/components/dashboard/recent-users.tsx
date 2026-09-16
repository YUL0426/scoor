"use client";

import { Users, Smartphone, Monitor } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatRelativeTime, scoorToColor, statusLabel } from "@/lib/utils";
import type { User } from "@/types";

function UserRow({ user }: { user: User }) {
  const initial = user.username[0]?.toUpperCase();
  const scoorColor = user.lastScoor !== null ? scoorToColor(user.lastScoor) : "#8b8e98";

  return (
    <div className="flex items-center gap-3 py-2.5 border-b border-white/4 last:border-0 hover:bg-white/2 rounded-lg px-2 -mx-2 transition-colors">
      {/* Avatar */}
      <div
        className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0 text-white"
        style={{ background: `${scoorColor}33`, color: scoorColor }}
      >
        {initial}
      </div>

      {/* User info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-1.5">
          <p className="text-xs font-medium text-[#ededee] truncate">{user.username}</p>
          {user.deviceOs === "ios" ? (
            <Smartphone className="h-2.5 w-2.5 text-[#8b8e98] flex-shrink-0" />
          ) : (
            <Monitor className="h-2.5 w-2.5 text-[#8b8e98] flex-shrink-0" />
          )}
        </div>
        <p className="text-[10px] text-[#8b8e98]">
          {user.countryCode} · {formatRelativeTime(user.lastActiveAt)}
        </p>
      </div>

      {/* Status + Score */}
      <div className="flex flex-col items-end gap-1">
        <Badge
          variant={
            user.status === "active"
              ? "success"
              : user.status === "suspended"
              ? "warning"
              : "danger"
          }
          dot
        >
          {statusLabel(user.status)}
        </Badge>
        {user.lastScoor !== null && (
          <span
            className="text-xs font-bold tabular-nums"
            style={{ color: scoorColor }}
          >
            {user.lastScoor}
          </span>
        )}
      </div>
    </div>
  );
}

interface RecentUsersProps {
  users: User[];
}

export function RecentUsers({ users }: RecentUsersProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Users className="h-4 w-4 text-[#a855f7]" />
          최근 사용자
        </CardTitle>
        <span className="text-xs text-[#8b8e98]">오늘 활성</span>
      </CardHeader>
      <CardContent className="py-2">
        {users.map((user) => (
          <UserRow key={user.id} user={user} />
        ))}
      </CardContent>
    </Card>
  );
}
