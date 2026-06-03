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
    label: "New Agenda",
    description: "Create world agenda",
    icon: Globe,
    color: "#4f8ef7",
  },
  {
    label: "Review Reports",
    description: "7 pending items",
    icon: ShieldAlert,
    color: "#f59e0b",
  },
  {
    label: "Send Notification",
    description: "Push to all users",
    icon: Bell,
    color: "#a855f7",
  },
  {
    label: "Export Report",
    description: "Download CSV data",
    icon: Download,
    color: "#22c55e",
  },
  {
    label: "View Analytics",
    description: "Deep dive metrics",
    icon: BarChart2,
    color: "#06b6d4",
  },
  {
    label: "Create Admin",
    description: "Invite team member",
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
        <CardTitle>Quick Actions</CardTitle>
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
