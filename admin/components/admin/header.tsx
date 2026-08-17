"use client";

import { Search, Bell, RefreshCw } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

interface HeaderProps {
  title: string;
  subtitle?: string;
}

export function Header({ title, subtitle }: HeaderProps) {
  const [searchFocused, setSearchFocused] = useState(false);

  return (
    <header className="flex items-center gap-4 h-14 px-6 border-b border-white/6 bg-[#060610]/80 backdrop-blur-sm flex-shrink-0">
      {/* Title area */}
      <div className="flex-1 min-w-0">
        <h1 className="text-sm font-semibold text-[#f4f4f6] truncate">{title}</h1>
        {subtitle && (
          <p className="text-xs text-[#52526c] truncate">{subtitle}</p>
        )}
      </div>

      {/* Search */}
      <div
        className={cn(
          "flex items-center gap-2 h-8 px-3 rounded-lg transition-all duration-200",
          "bg-white/5 border",
          searchFocused
            ? "border-[#f42525]/40 w-64"
            : "border-white/8 hover:border-white/14 w-48"
        )}
      >
        <Search className="h-3.5 w-3.5 text-[#52526c] flex-shrink-0" />
        <input
          type="text"
          placeholder="검색..."
          className="flex-1 bg-transparent text-xs text-[#f4f4f6] placeholder:text-[#52526c] outline-none min-w-0"
          onFocus={() => setSearchFocused(true)}
          onBlur={() => setSearchFocused(false)}
        />
        <kbd className="hidden sm:inline-flex items-center gap-1 text-[10px] text-[#52526c] border border-white/10 rounded px-1 py-0.5">
          ⌘K
        </kbd>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-1">
        <button className="relative flex items-center justify-center w-8 h-8 rounded-lg text-[#52526c] hover:text-[#f4f4f6] hover:bg-white/5 transition-colors">
          <Bell className="h-4 w-4" />
          <span className="absolute top-1.5 right-1.5 w-1.5 h-1.5 bg-[#f42525] rounded-full" />
        </button>
        <button className="flex items-center justify-center w-8 h-8 rounded-lg text-[#52526c] hover:text-[#f4f4f6] hover:bg-white/5 transition-colors">
          <RefreshCw className="h-4 w-4" />
        </button>

        {/* Live badge */}
        <div className="flex items-center gap-1.5 px-2.5 py-1 bg-emerald-500/10 border border-emerald-500/20 rounded-full ml-1">
          <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
          <span className="text-[10px] font-medium text-emerald-400">실시간</span>
        </div>
      </div>
    </header>
  );
}
