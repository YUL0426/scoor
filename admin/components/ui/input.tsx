"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export function Input({
  label,
  error,
  leftIcon,
  rightIcon,
  className,
  id,
  ...props
}: InputProps) {
  const generatedId = React.useId();
  const inputId = id ?? generatedId;

  return (
    <div className="flex flex-col gap-1.5 w-full">
      {label && (
        <label
          htmlFor={inputId}
          className="text-xs font-medium text-[#a2a4ac] uppercase tracking-wider"
        >
          {label}
        </label>
      )}
      <div className="relative">
        {leftIcon && (
          <span className="absolute left-3 top-1/2 -translate-y-1/2 text-[#8b8e98]">
            {leftIcon}
          </span>
        )}
        <input
          id={inputId}
          className={cn(
            "w-full h-10 rounded-lg bg-white/5 border border-white/10",
            "text-sm text-[#ededee] placeholder:text-[#8b8e98]",
            "px-3",
            "transition-all duration-150",
            "hover:border-white/16 focus:outline-none focus:border-[#e36b59]/60 focus:ring-2 focus:ring-[#e36b59]/10",
            leftIcon && "pl-9",
            rightIcon && "pr-9",
            error &&
              "border-red-500/50 focus:border-red-500/70 focus:ring-red-500/10",
            className,
          )}
          {...props}
        />
        {rightIcon && (
          <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[#8b8e98]">
            {rightIcon}
          </span>
        )}
      </div>
      {error && <p className="text-xs text-red-400">{error}</p>}
    </div>
  );
}
