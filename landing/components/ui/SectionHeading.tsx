import { Reveal } from "@/components/motion/Reveal";
import { cn } from "@/lib/utils";

export function SectionHeading({
  eyebrow,
  title,
  subtitle,
  align = "center",
  className,
}: {
  eyebrow?: string;
  title: React.ReactNode;
  subtitle?: string;
  align?: "center" | "left";
  className?: string;
}) {
  return (
    <div
      className={cn(
        "max-w-2xl",
        align === "center" ? "mx-auto text-center" : "text-left",
        className
      )}
    >
      {eyebrow && (
        <Reveal>
          <span className="inline-block rounded-full bg-[var(--color-brand-tint)] px-3 py-1 text-xs font-semibold uppercase tracking-wider text-[var(--color-brand)]">
            {eyebrow}
          </span>
        </Reveal>
      )}
      <Reveal index={1}>
        <h2 className="mt-4 text-balance text-4xl font-bold tracking-tight sm:text-5xl">
          {title}
        </h2>
      </Reveal>
      {subtitle && (
        <Reveal index={2}>
          <p className="mt-4 text-balance text-lg text-[var(--color-text-2)]">
            {subtitle}
          </p>
        </Reveal>
      )}
    </div>
  );
}
