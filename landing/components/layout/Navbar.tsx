"use client";

import { useEffect, useState } from "react";
import { ScoorWordmark } from "@/components/brand/ScoorWordmark";
import { Button } from "@/components/ui/Button";
import { DEEP_LINKS } from "@/lib/site";
import { cn } from "@/lib/utils";

const LINKS = [
  { href: "#how", label: "How it works" },
  { href: "#world", label: "World" },
  { href: "#insights", label: "Insights" },
  { href: "#social", label: "Social" },
];

export function Navbar() {
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 12);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 transition-all duration-300",
        scrolled ? "py-2.5" : "py-4"
      )}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between px-5">
        <div
          className={cn(
            "flex w-full items-center justify-between rounded-full px-4 transition-all duration-300",
            scrolled
              ? "glass py-2 shadow-[0_8px_30px_-12px_rgba(0,0,0,0.18)] ring-1 ring-[var(--color-line)]"
              : "py-1"
          )}
        >
          <a href="#top" aria-label="Scoor home" className="flex items-center pl-1">
            <ScoorWordmark height={22} priority />
          </a>
          <nav className="hidden items-center gap-7 md:flex">
            {LINKS.map((l) => (
              <a
                key={l.href}
                href={l.href}
                className="text-sm font-medium text-[var(--color-text-2)] transition-colors hover:text-[var(--color-text)]"
              >
                {l.label}
              </a>
            ))}
          </nav>
          <Button href={DEEP_LINKS.open.web} size="sm" className="ml-2">
            Get the app
          </Button>
        </div>
      </div>
    </header>
  );
}
