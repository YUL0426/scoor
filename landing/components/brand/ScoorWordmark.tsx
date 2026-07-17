import Image from "next/image";
import redMark from "@/public/scoor-wordmark-red.png";
import whiteMark from "@/public/scoor-wordmark-white.png";
import { cn } from "@/lib/utils";

/**
 * Official Scoor wordmark lockup. Mirrors the in-app `ScoorLogo` convention:
 * `red` on light backgrounds, `white` on dark. Height is the control; width
 * auto-scales (~1.65:1). Never render the brand as plain text.
 */
export function ScoorWordmark({
  variant = "red",
  height = 28,
  className,
  priority,
}: {
  variant?: "red" | "white";
  height?: number;
  className?: string;
  priority?: boolean;
}) {
  const src = variant === "white" ? whiteMark : redMark;
  return (
    <Image
      src={src}
      alt="Scoor"
      height={height}
      width={Math.round(height * 1.65)}
      priority={priority}
      className={cn("h-auto w-auto select-none", className)}
      style={{ height }}
    />
  );
}
