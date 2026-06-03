import * as React from "react";
import { cn } from "@/lib/utils";

type BadgeVariant =
  | "default"
  | "success"
  | "warning"
  | "danger"
  | "info"
  | "neutral"
  | "trending";

interface BadgeProps extends React.HTMLAttributes<HTMLSpanElement> {
  variant?: BadgeVariant;
  dot?: boolean;
}

export function Badge({
  variant = "default",
  dot = false,
  className,
  children,
  ...props
}: BadgeProps) {
  const base =
    "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium tabular-nums";

  const variants: Record<BadgeVariant, string> = {
    default: "bg-white/8 text-[#8b8ba4] border border-white/6",
    success: "bg-emerald-500/12 text-emerald-400 border border-emerald-500/20",
    warning: "bg-amber-500/12 text-amber-400 border border-amber-500/20",
    danger: "bg-red-500/12 text-red-400 border border-red-500/20",
    info: "bg-blue-500/12 text-blue-400 border border-blue-500/20",
    neutral: "bg-white/6 text-[#8b8ba4] border border-white/8",
    trending:
      "bg-[#f42525]/12 text-[#f42525] border border-[#f42525]/20 font-semibold",
  };

  const dotColors: Record<BadgeVariant, string> = {
    default: "bg-[#8b8ba4]",
    success: "bg-emerald-400",
    warning: "bg-amber-400",
    danger: "bg-red-400",
    info: "bg-blue-400",
    neutral: "bg-[#8b8ba4]",
    trending: "bg-[#f42525] animate-pulse",
  };

  return (
    <span className={cn(base, variants[variant], className)} {...props}>
      {dot && (
        <span
          className={cn("h-1.5 w-1.5 rounded-full flex-shrink-0", dotColors[variant])}
        />
      )}
      {children}
    </span>
  );
}
