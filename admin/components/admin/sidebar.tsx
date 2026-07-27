"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Users,
  Globe,
  Rss,
  Bell,
  BarChart2,
  Settings,
  LogOut,
  Zap,
  ChevronRight,
  ListChecks,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useAuth } from "@/providers/auth-provider";

/// Grouped by a field rather than by index slices: the previous form hard-coded
/// `slice(0, 4)` / `slice(4, 6)` / `[6]`, so adding one item silently moved
/// another into the wrong section.
const NAV_GROUPS = [
  {
    title: "Operations",
    items: [
      { label: "Dashboard", href: "/admin", icon: LayoutDashboard, exact: true },
      { label: "Users", href: "/admin/users", icon: Users },
      { label: "World Topics", href: "/admin/topics", icon: ListChecks },
      { label: "World Agenda", href: "/admin/agenda", icon: Globe },
      { label: "Feed", href: "/admin/feed", icon: Rss },
    ],
  },
  {
    title: "Insights",
    items: [
      { label: "Notifications", href: "/admin/notifications", icon: Bell },
      { label: "Analytics", href: "/admin/analytics", icon: BarChart2 },
    ],
  },
  {
    title: "System",
    items: [{ label: "Settings", href: "/admin/settings", icon: Settings }],
  },
] as const;

function NavItem({
  href,
  label,
  icon: Icon,
  exact,
}: {
  href: string;
  label: string;
  icon: React.ElementType;
  exact?: boolean;
}) {
  const pathname = usePathname();
  const isActive = exact ? pathname === href : pathname.startsWith(href);

  return (
    <Link
      href={href}
      className={cn(
        "group flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-all duration-150 relative",
        isActive
          ? "bg-[#f42525]/12 text-[#f42525]"
          : "text-[#8b8ba4] hover:text-[#f4f4f6] hover:bg-white/5"
      )}
    >
      {isActive && (
        <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-5 bg-[#f42525] rounded-r-full" />
      )}
      <Icon
        className={cn(
          "h-4 w-4 flex-shrink-0 transition-colors",
          isActive ? "text-[#f42525]" : "text-[#52526c] group-hover:text-[#8b8ba4]"
        )}
      />
      <span>{label}</span>
      {isActive && (
        <ChevronRight className="ml-auto h-3.5 w-3.5 text-[#f42525]/60" />
      )}
    </Link>
  );
}

export function Sidebar() {
  const { logout, user } = useAuth();

  return (
    <aside className="flex flex-col h-full w-56 bg-[#060610] border-r border-white/6">
      {/* Logo */}
      <div className="flex items-center gap-3 px-4 h-14 border-b border-white/6 flex-shrink-0">
        <div className="flex items-center justify-center w-7 h-7 rounded-lg bg-[#f42525] shadow-[0_0_12px_rgba(244,37,37,0.35)]">
          <Zap className="h-3.5 w-3.5 text-white" strokeWidth={2.5} />
        </div>
        <div className="flex flex-col">
          <span className="text-sm font-bold text-[#f4f4f6] tracking-tight leading-none">
            scoor
          </span>
          <span className="text-[10px] text-[#52526c] font-medium uppercase tracking-widest">
            admin
          </span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 overflow-y-auto py-4 px-2 space-y-0.5">
        {NAV_GROUPS.map((group, index) => (
          <div key={group.title}>
            <div className={cn("px-2 mb-2", index > 0 && "mt-4")}>
              <span className="text-[10px] font-semibold text-[#52526c] uppercase tracking-widest">
                {group.title}
              </span>
            </div>
            <div className="space-y-0.5">
              {group.items.map((item) => (
                <NavItem key={item.href} {...item} />
              ))}
            </div>
          </div>
        ))}
      </nav>

      {/* User area */}
      <div className="flex-shrink-0 border-t border-white/6 p-3">
        <div className="flex items-center gap-2.5 px-2 py-2 rounded-lg">
          <div className="flex items-center justify-center w-7 h-7 rounded-full bg-gradient-to-br from-[#f42525] to-[#ff8a80] text-white text-xs font-bold flex-shrink-0">
            {user?.name?.[0]?.toUpperCase() ?? "A"}
          </div>
          <div className="flex-1 min-w-0">
            <p className="text-xs font-medium text-[#f4f4f6] truncate">
              {user?.name ?? "Admin"}
            </p>
            <p className="text-[10px] text-[#52526c] truncate">
              {user?.email ?? "admin@scoor.app"}
            </p>
          </div>
          <button
            onClick={logout}
            className="text-[#52526c] hover:text-red-400 transition-colors p-1 rounded"
            title="Sign out"
          >
            <LogOut className="h-3.5 w-3.5" />
          </button>
        </div>
      </div>
    </aside>
  );
}
