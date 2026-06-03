import { Header } from "@/components/admin/header";
import { Bell, AlertTriangle, Info, Zap } from "lucide-react";
import { Badge } from "@/components/ui/badge";

const MOCK_NOTIFICATIONS = [
  {
    id: "n1",
    type: "spike_detected",
    title: "Emotional Spike Detected",
    body: "Brazil scores jumped +22 points in the last hour. Copa América final appears to be driving record positivity.",
    severity: "info",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 12).toISOString(),
  },
  {
    id: "n2",
    type: "new_report",
    title: "New Moderation Reports",
    body: "3 new reports filed in the last 30 minutes. 2 are hate speech, 1 is spam.",
    severity: "warning",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 35).toISOString(),
  },
  {
    id: "n3",
    type: "user_flagged",
    title: "High-Risk User Flagged",
    body: "User 'toxic_troll_99' has accumulated 5 reports in 24 hours. Auto-flagged for review.",
    severity: "critical",
    isRead: false,
    createdAt: new Date(Date.now() - 1000 * 60 * 58).toISOString(),
  },
  {
    id: "n4",
    type: "agenda_expired",
    title: "Agenda Expired",
    body: "World agenda 'Mental Health Awareness Month' ends in 4 days. Consider renewal.",
    severity: "info",
    isRead: true,
    createdAt: new Date(Date.now() - 1000 * 60 * 60 * 3).toISOString(),
  },
  {
    id: "n5",
    type: "system_alert",
    title: "Daily Digest Ready",
    body: "Platform summary: DAU +12.4%, total scoors today: 31,204, avg score: 67.3.",
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
      <Header title="Notifications" subtitle={`${unread} unread`} />
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
