import { cva, type VariantProps } from "class-variance-authority";
import type { AnchorHTMLAttributes } from "react";
import { cn } from "@/lib/utils";

const button = cva(
  "inline-flex items-center justify-center gap-2 rounded-full font-semibold tracking-tight transition-all duration-300 ease-[cubic-bezier(0.16,1,0.3,1)] active:scale-[0.97] focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-[var(--color-brand)]/25 disabled:opacity-50",
  {
    variants: {
      variant: {
        primary:
          "bg-[var(--color-brand)] text-white shadow-[0_8px_24px_-8px_rgba(206,59,34,0.6)] hover:bg-[var(--color-brand-dark)] hover:shadow-[0_12px_32px_-8px_rgba(206,59,34,0.7)] hover:-translate-y-0.5",
        dark: "bg-[var(--color-ink)] text-white hover:bg-black hover:-translate-y-0.5",
        ghost:
          "bg-white/70 text-[var(--color-text)] ring-1 ring-[var(--color-line-strong)] backdrop-blur hover:bg-white",
        outline:
          "border border-[var(--color-line-strong)] text-[var(--color-text)] hover:bg-white",
      },
      size: {
        sm: "h-10 px-5 text-sm",
        md: "h-12 px-7 text-[15px]",
        lg: "h-14 px-9 text-base",
      },
    },
    defaultVariants: { variant: "primary", size: "md" },
  }
);

export interface ButtonProps
  extends AnchorHTMLAttributes<HTMLAnchorElement>,
    VariantProps<typeof button> {}

export function Button({
  className,
  variant,
  size,
  ...props
}: ButtonProps) {
  return (
    <a className={cn(button({ variant, size }), className)} {...props} />
  );
}
