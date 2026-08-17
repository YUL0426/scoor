import { Header } from "@/components/admin/header";
import { KPICard } from "@/components/dashboard/kpi-card";
import { ScoorTrendChart } from "@/components/dashboard/scoor-trend-chart";
import { WorldPulse } from "@/components/dashboard/world-pulse";
import { RecentAgendas } from "@/components/dashboard/recent-agendas";
import { RecentReports } from "@/components/dashboard/recent-reports";
import { RecentUsers } from "@/components/dashboard/recent-users";
import { RecentFeed } from "@/components/dashboard/recent-feed";
import { QuickActions } from "@/components/dashboard/quick-actions";
import { getDashboardMetrics, getScoorTrend, getWorldPulse } from "@/lib/api/dashboard";
import { mockAgendas } from "@/lib/mock/agendas";
import { mockUsers } from "@/lib/mock/users";
import { mockFeedEntries } from "@/lib/mock/feed";
import { mockReports } from "@/lib/mock/reports";

const KPI_ACCENT_COLORS = [
  "#f42525",
  "#4f8ef7",
  "#a855f7",
  "#22c55e",
  "#f59e0b",
  "#06b6d4",
];

export default async function DashboardPage() {
  const [metrics, trend, worldPulse] = await Promise.all([
    getDashboardMetrics(),
    getScoorTrend(30),
    getWorldPulse(),
  ]);

  const kpiEntries = [
    metrics.dau,
    metrics.wau,
    metrics.todayScoorCount,
    metrics.avgScoor,
    metrics.activeAgendas,
    metrics.pendingReports,
  ];

  return (
    <div className="flex-1 overflow-y-auto">
      <Header
        title="대시보드"
        subtitle={`Scoor 운영 — ${new Date().toLocaleDateString("ko-KR", { weekday: "long", year: "numeric", month: "long", day: "numeric" })}`}
      />

      <div className="p-6 space-y-6">
        {/* KPI Cards Row */}
        <section>
          <div className="grid grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
            {kpiEntries.map((metric, i) => (
              <div
                key={metric.label}
                className={i < 4 ? "xl:col-span-1" : "xl:col-span-1"}
              >
                <KPICard
                  metric={metric}
                  accentColor={KPI_ACCENT_COLORS[i]}
                />
              </div>
            ))}
          </div>
        </section>

        {/* Middle row: Chart + World Pulse */}
        <section className="grid grid-cols-1 xl:grid-cols-3 gap-4">
          <div className="xl:col-span-2">
            <ScoorTrendChart data={trend} />
          </div>
          <div className="xl:col-span-1">
            <WorldPulse data={worldPulse} />
          </div>
        </section>

        {/* Second middle row: Agendas + Reports */}
        <section className="grid grid-cols-1 xl:grid-cols-2 gap-4">
          <RecentAgendas agendas={mockAgendas.slice(0, 5)} />
          <RecentReports reports={mockReports.slice(0, 4)} />
        </section>

        {/* Bottom row: Users + Feed + Quick Actions */}
        <section className="grid grid-cols-1 xl:grid-cols-3 gap-4">
          <RecentUsers users={mockUsers.slice(0, 5)} />
          <RecentFeed entries={mockFeedEntries} />
          <QuickActions />
        </section>
      </div>
    </div>
  );
}
