import { Header } from "@/components/admin/header";
import { Bell, AlertTriangle, Info, Zap } from "lucide-react";
import { Badge } from "@/components/ui/badge";

const MOCK_NOTIFICATIONS = [
  {
    id: "n1",
    type: "spike_detected",
    title: "감정 급변 감지",
    body: "최근 1시간 동안 브라질 점수가 +22 상승했습니다. 코파 아메리카 결승이 기록적인 긍정 반응을 이끄는 것으로 보입니다.",
    severity: "info",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
  },
  {
    id: "n2",
    type: "new_report",
    title: "새 신고 접수",
    body: "최근 30분간 신고 3건이 접수됐습니다. 혐오 발언 2건, 스팸 1건입니다.",
    severity: "warning",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 35).toISOString(),
  },
  {
    id: "n3",
    type: "user_flagged",
    title: "고위험 사용자 표시",
    body: "사용자 'toxic_troll_99'가 24시간 내 신고 5건을 받았습니다. 검토 대상으로 자동 표시됐습니다.",
    severity: "critical",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 58).toISOString(),
  },
  {
    id: "n4",
    type: "agenda_expired",
    title: "아젠다 만료 임박",
    body: "월드 아젠다 '정신건강 인식의 달'이 4일 후 종료됩니다. 갱신을 검토해주세요.",
    severity: "info",
    isRead: true,
    createdAt: new Date(Date.now() - 1000 * 60 * 60 * 3).toISOString(),
  },
  {
    id: "n5",
    type: "system_alert",
    title: "일간 요약 준비 완료",
    body: "플랫폼 요약: 일간 활성 사용자 +12.4%, 오늘 총 점수 기록 31,204건, 평균 점수 67.3.",
    severity: "info",
    isRead: true,
    createdAt: new Date(Date.now() - 1000 * 60 * 60 * 8).toISOString(),
  },
];

function NotificationIcon({ severity }: { severity: string }) {
  if (severity === "critical") return <AlertTriangle className="h-4 w-4 text-red-400" />;
  if (severity === "warning") return <AlertTriangle className="h-4 w-4 text-amber-400" />;
  return <Info className="h-4 w-4 text-blue-400" />;
}

export default function NotificationsPage() {
  const unread = MOCK_NOTIFICATIONS.filter((n) => !n.isRead).length;

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="알림" subtitle={`읽지 않음 ${unread}건`} />
      <div className="flex-1 overflow-y-auto p-6">
        <div className="max-w-2xl space-y-2">
          {MOCK_NOTIFICATIONS.map((n) => (
            <div
              key={n.id}
              className={`flex items-start gap-4 p-4 rounded-xl border transition-all ${
                n.isRead
                  ? "bg-[#0d0d1f]/50 border-white/4"
                  : "bg-[#0d0d1f] border-white/8"
              }`}
            >
              <div
                className={`flex items-center justify-center w-9 h-9 rounded-lg flex-shrink-0 ${
                  n.severity === "critical"
                    ? "bg-red-500/12"
                    : n.severity === "warning"
                    ? "bg-amber-500/12"
                    : "bg-blue-500/12"
                }`}
              >
                <NotificationIcon severity={n.severity} />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <p
                    className={`text-sm font-medium ${
                      n.isRead ? "text-[#8b8ba4]" : "text-[#f4f4f6]"
                    }`}
                  >
                    {n.title}
                  </p>
                  {!n.isRead && (
                    <span className="w-1.5 h-1.5 bg-[#f42525] rounded-full flex-shrink-0" />
                  )}
                </div>
                <p className="text-xs text-[#52526c]">{n.body}</p>
              </div>
              <div className="flex-shrink-0 text-[10px] text-[#52526c] whitespace-nowrap">
                {new Date(n.createdAt).toLocaleTimeString("en-US", {
                  hour: "2-digit",
                  minute: "2-digit",
                })}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
