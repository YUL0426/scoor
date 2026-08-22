import { Header } from "@/components/admin/header";
import { getScoorTrend } from "@/lib/api/dashboard";
import { AnalyticsClient } from "./analytics-client";

export default async function AnalyticsPage() {
  const trend = await getScoorTrend(30);
  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      <Header title="분석" subtitle="플랫폼 성과 지표" />
      <AnalyticsClient trend={trend} />
    </div>
  );
}
