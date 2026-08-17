import { Header } from "@/components/admin/header";
import { Badge } from "@/components/ui/badge";
import { mockUsers } from "@/lib/mock/users";
import { formatRelativeTime, scoorToColor, statusLabel } from "@/lib/utils";
import { Smartphone, Monitor, Flame } from "lucide-react";

export default function UsersPage() {
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header
        title="사용자"
        subtitle={`${mockUsers.length}명 추적 중`}
      />
      <div className="flex-1 overflow-y-auto p-6">
        {/* Stats bar */}
        <div className="grid grid-cols-4 gap-4 mb-6">
          {[
            { label: "전체 사용자", value: "142.4K", color: "#f42525" },
            { label: "오늘 활성", value: "24.9K", color: "#22c55e" },
            { label: "이번 주 신규", value: "1,240", color: "#4f8ef7" },
            { label: "정지", value: "38", color: "#f59e0b" },
          ].map((s) => (
            <div
              key={s.label}
              className="bg-[#0d0d1f] border border-white/6 rounded-xl px-5 py-4"
            >
              <p className="text-xs text-[#52526c] uppercase tracking-wider mb-1">
                {s.label}
              </p>
              <p className="text-2xl font-bold tabular-nums" style={{ color: s.color }}>
                {s.value}
              </p>
            </div>
          ))}
        </div>

        {/* Users table */}
        <div className="bg-[#0d0d1f] border border-white/6 rounded-xl overflow-hidden">
          <table className="w-full text-xs">
            <thead>
              <tr className="border-b border-white/6">
                {["사용자", "국가", "상태", "최근 점수", "연속", "기기", "최근 활동"].map(
                  (h) => (
                    <th
                      key={h}
                      className="text-left px-4 py-3 text-[10px] font-semibold text-[#52526c] uppercase tracking-wider"
                    >
                      {h}
                    </th>
                  )
                )}
              </tr>
            </thead>
            <tbody>
              {mockUsers.map((user) => {
                const color =
                  user.lastScoor !== null ? scoorToColor(user.lastScoor) : "#52526c";
                return (
                  <tr
                    key={user.id}
                    className="border-b border-white/4 hover:bg-white/2 transition-colors"
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="w-7 h-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0"
                          style={{ background: `${color}22`, color }}
                        >
                          {user.username[0]?.toUpperCase()}
                        </div>
                        <div>
                          <p className="font-medium text-[#f4f4f6]">{user.username}</p>
                          <p className="text-[#52526c] text-[10px]">{user.email}</p>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3 text-[#8b8ba4]">
                      {user.countryCode} · {user.country}
                    </td>
                    <td className="px-4 py-3">
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
                    </td>
                    <td className="px-4 py-3">
                      {user.lastScoor !== null ? (
                        <span
                          className="font-bold tabular-nums text-sm"
                          style={{ color }}
                        >
                          {user.lastScoor}
                        </span>
                      ) : (
                        <span className="text-[#52526c]">—</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span className="flex items-center gap-1 text-[#8b8ba4]">
                        {user.streakDays > 30 && (
                          <Flame className="h-3 w-3 text-orange-400" />
                        )}
                        {user.streakDays}일
                      </span>
                    </td>
                    <td className="px-4 py-3 text-[#52526c]">
                      {user.deviceOs === "ios" ? (
                        <Smartphone className="h-3.5 w-3.5" />
                      ) : (
                        <Monitor className="h-3.5 w-3.5" />
                      )}
                    </td>
                    <td className="px-4 py-3 text-[#52526c] tabular-nums">
                      {formatRelativeTime(user.lastActiveAt)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
