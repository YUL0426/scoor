"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: "primary" | "ghost" | "outline" | "danger";
  size?: "sm" | "md" | "lg";
  loading?: boolean;
}

export function Button({
  variant = "primary",
  size = "md",
  loading = false,
  className,
  children,
  disabled,
  ...props
}: ButtonProps) {
  const base =
    "inline-flex items-center justify-center gap-2 font-medium rounded-lg transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-40 select-none";

  const variants = {
    primary:
      "bg-[#f42525] hover:bg-[#d41f1f] active:bg-[#bf1c1c] text-white shadow-sm focus-visible:ring-[#f42525] focus-visible:ring-offset-[#060610]",
    ghost:
      "bg-transparent hover:bg-white/5 active:bg-white/8 text-[#8b8ba4] hover:text-[#f4f4f6]",
    outline:
      "border border-white/10 hover:border-white/20 bg-transparent hover:bg-white/4 text-[#f4f4f6]",
    danger:
      "bg-red-900/30 hover:bg-red-800/40 border border-red-500/30 text-red-400",
  };

  const sizes = {
    sm: "h-7 px-3 text-xs",
    md: "h-9 px-4 text-sm",
    lg: "h-11 px-6 text-base",
  };

  return (
    <button
      className={cn(base, variants[variant], sizes[size], className)}
      disabled={disabled || loading}
      {...props}
    >
      {loading && (
        <svg
          className="h-3.5 w-3.5 animate-spin"
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
          />
        </svg>
      )}
      {children}
    </button>
  );
}
