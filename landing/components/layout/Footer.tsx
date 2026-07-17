import { ScoorWordmark } from "@/components/brand/ScoorWordmark";
import { AppStoreBadge, PlayStoreBadge } from "@/components/ui/StoreBadges";
import { SITE } from "@/lib/site";

const COLS = [
  {
    title: "Product",
    links: [
      ["How it works", "#how"],
      ["World scores", "#world"],
      ["Insights", "#insights"],
      ["Social", "#social"],
    ],
  },
  {
    title: "Company",
    links: [
      ["About", "#"],
      ["Careers", "#"],
      ["Press", "#"],
      ["Blog", "#"],
    ],
  },
  {
    title: "Legal",
    links: [
      ["Privacy", "#"],
      ["Terms", "#"],
      ["Cookies", "#"],
      ["Guidelines", "#"],
    ],
  },
];

export function Footer() {
  return (
    <footer className="border-t border-[var(--color-line)] bg-[var(--color-ink)] text-white">
      <div className="mx-auto grid max-w-6xl gap-12 px-6 py-16 md:grid-cols-[1.4fr_1fr_1fr_1fr]">
        <div>
          <ScoorWordmark variant="white" height={26} />
          <p className="mt-4 max-w-xs text-sm leading-relaxed text-white/55">
            The social scoring app. Score your day, score the world, and see how
            everyone feels.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <AppStoreBadge />
            <PlayStoreBadge />
          </div>
        </div>
        {COLS.map((col) => (
          <div key={col.title}>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-white/40">
              {col.title}
            </h4>
            <ul className="mt-4 space-y-3">
              {col.links.map(([label, href]) => (
                <li key={label}>
                  <a href={href} className="text-sm text-white/65 transition-colors hover:text-white">
                    {label}
                  </a>
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-white/10">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-3 px-6 py-6 text-xs text-white/40 sm:flex-row">
          <p>© {new Date().getFullYear()} Scoor. All rights reserved.</p>
          <p>{SITE.tagline}</p>
        </div>
      </div>
    </footer>
  );
}
