"use client";

import { ShieldAlert, Clock } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { formatRelativeTime, statusLabel } from "@/lib/utils";
import type { Report, ReportReason } from "@/types";

const REASON_LABELS: Record<ReportReason, string> = {
  spam: "스팸",
  hate_speech: "혐오 발언",
  misinformation: "허위 정보",
  harassment: "괴롭힘",
  inappropriate: "부적절한 콘텐츠",
};

function ReportRow({ report }: { report: Report }) {
  return (
    <div className="flex items-start gap-3 py-2.5 border-b border-white/4 last:border-0 hover:bg-white/2 rounded-lg px-2 -mx-2 transition-colors">
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-1">
          <Badge
            variant={
              report.status === "pending"
                ? "warning"
                : report.status === "resolved"
                ? "success"
                : report.status === "reviewed"
                ? "info"
                : "neutral"
            }
            dot
          >
            {statusLabel(report.status)}
          </Badge>
          <span className="text-[10px] text-[#52526c]">
            {REASON_LABELS[report.reason]}
          </span>
        </div>
        <p className="text-xs text-[#8b8ba4] truncate">{report.targetSummary}</p>
        <p className="text-[10px] text-[#52526c] mt-0.5">
          by {report.reporterUsername}
        </p>
      </div>
      <div className="flex items-center gap-1 flex-shrink-0 text-[10px] text-[#52526c]">
        <Clock className="h-2.5 w-2.5" />
        {formatRelativeTime(report.createdAt)}
      </div>
    </div>
  );
}

interface RecentReportsProps {
  reports: Report[];
}

export function RecentReports({ reports }: RecentReportsProps) {
  const pending = reports.filter((r) => r.status === "pending");

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <ShieldAlert className="h-4 w-4 text-amber-400" />
          신고 처리 대기
        </CardTitle>
        {pending.length > 0 && (
          <Badge variant="warning" dot>
            {pending.length}건 대기
          </Badge>
        )}
      </CardHeader>
      <CardContent className="py-2">
        {reports.length === 0 ? (
          <p className="text-xs text-[#52526c] py-4 text-center">처리할 신고 없음 ✓</p>
        ) : (
          reports.map((r) => <ReportRow key={r.id} report={r} />)
        )}
      </CardContent>
    </Card>
  );
}
