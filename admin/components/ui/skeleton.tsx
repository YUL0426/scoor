import * as React from "react";
import { cn } from "@/lib/utils";

interface SkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  height?: string | number;
  width?: string | number;
  rounded?: "sm" | "md" | "lg" | "full";
}

export function Skeleton({ height, width, rounded = "md", className, style, ...props }: SkeletonProps) {
  const radiusMap = {
    sm: "rounded",
    md: "rounded-lg",
    lg: "rounded-xl",
    full: "rounded-full",
  };

  return (
    <div
      className={cn(
        "animate-pulse bg-white/5",
        radiusMap[rounded],
        className
      )}
      style={{ height, width, ...style }}
      {...props}
    />
  );
}

export function KPICardSkeleton() {
  return (
    <div className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5 flex flex-col gap-4">
      <Skeleton height={12} width={120} />
      <Skeleton height={36} width={90} />
      <div className="flex items-center gap-2">
        <Skeleton height={10} width={60} />
        <Skeleton height={10} width={80} />
      </div>
      <Skeleton height={36} />
    </div>
  );
}

export function TableRowSkeleton({ cols = 5 }: { cols?: number }) {
  return (
    <tr className="border-b border-white/4">
      {Array.from({ length: cols }).map((_, i) => (
        <td key={i} className="px-4 py-3">
          <Skeleton height={14} width={`${60 + Math.random() * 40}%`} />
        </td>
      ))}
    </tr>
  );
}
