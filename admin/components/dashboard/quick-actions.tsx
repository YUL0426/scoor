"use client";

import { Plus, ShieldAlert, BarChart2, Download, Bell, Globe } from "lucide-react";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { cn } from "@/lib/utils";

interface QuickAction {
  label: string;
  description: string;
  icon: React.ElementType;
  color: string;
  onClick?: () => void;
}

const ACTIONS: QuickAction[] = [
  {
    label: "새 아젠다",
    description: "월드 아젠다 생성",
    icon: Globe,
    color: "#4f8ef7",
  },
  {
    label: "신고 검토",
    description: "7 pending items",
    icon: ShieldAlert,
    color: "#f59e0b",
  },
  {
    label: "알림 발송",
    description: "전체 사용자에게 푸시",
    icon: Bell,
    color: "#a855f7",
  },
  {
    label: "리포트 내보내기",
    description: "CSV 데이터 다운로드",
    icon: Download,
    color: "#22c55e",
  },
  {
    label: "분석 보기",
    description: "지표 상세 분석",
    icon: BarChart2,
    color: "#06b6d4",
  },
  {
    label: "관리자 추가",
    description: "팀원 초대",
    icon: Plus,
    color: "#f42525",
  },
];

function ActionItem({ action }: { action: QuickAction }) {
  const Icon = action.icon;

  return (
    <button
      onClick={action.onClick}
      className="flex items-center gap-3 w-full px-3 py-2.5 rounded-lg border border-white/6 hover:border-white/12 hover:bg-white/3 transition-all duration-150 group text-left"
    >
      <div
        className="flex items-center justify-center w-7 h-7 rounded-lg flex-shrink-0"
        style={{ background: `${action.color}18` }}
      >
        <Icon
          className="h-3.5 w-3.5"
          style={{ color: action.color }}
        />
      </div>
      <div className="min-w-0">
        <p className="text-xs font-medium text-[#f4f4f6] truncate">{action.label}</p>
        <p className="text-[10px] text-[#52526c] truncate">{action.description}</p>
      </div>
    </button>
  );
}

export function QuickActions() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>빠른 작업</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-2">
          {ACTIONS.map((action) => (
            <ActionItem key={action.label} action={action} />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
