import * as React from "react";
import { cn } from "@/lib/utils";

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?: "default" | "elevated" | "ghost";
  glow?: "none" | "brand" | "blue" | "green";
}

export function Card({
  variant = "default",
  glow = "none",
  className,
  children,
  ...props
}: CardProps) {
  const variants = {
    default:
      "bg-[#0d0d1f] border border-white/6 rounded-xl",
    elevated:
      "bg-[#13131f] border border-white/8 rounded-xl",
    ghost:
      "bg-transparent border border-white/6 rounded-xl",
  };

  const glows = {
    none: "",
    brand: "shadow-[0_0_30px_rgba(244,37,37,0.08)]",
    blue: "shadow-[0_0_30px_rgba(79,142,247,0.08)]",
    green: "shadow-[0_0_30px_rgba(34,197,94,0.08)]",
  };

  return (
    <div
      className={cn(variants[variant], glows[glow], className)}
      {...props}
    >
      {children}
    </div>
  );
}

export function CardHeader({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn("flex items-center justify-between px-5 py-4 border-b border-white/5", className)} {...props}>
      {children}
    </div>
  );
}

export function CardTitle({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={cn("text-sm font-semibold text-[#f4f4f6] tracking-tight", className)}
      {...props}
    >
      {children}
    </h3>
  );
}

export function CardContent({
  className,
  children,
  ...props
}: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn("p-5", className)} {...props}>
      {children}
    </div>
  );
}
