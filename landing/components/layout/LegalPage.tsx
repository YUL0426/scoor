import type { ReactNode } from "react";
import Link from "next/link";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

/**
 * Shared shell for legal documents (/privacy, /terms, and their /ko variants).
 *
 * `altHref` carries the other language. Scoor launches in Korea first, so a
 * Korean reader has to be able to reach a Korean document from whichever URL
 * they landed on — a policy someone cannot read is not much of a policy.
 */
export function LegalPage({
  title,
  updated,
  updatedLabel = "Last updated",
  altHref,
  altLabel,
  children,
}: {
  title: string;
  updated: string;
  updatedLabel?: string;
  altHref?: string;
  altLabel?: string;
  children: ReactNode;
}) {
  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-3xl px-6 pb-24 pt-32">
        <div className="flex items-baseline justify-between gap-4">
          <h1 className="text-4xl font-bold tracking-tight">{title}</h1>
          {altHref && altLabel && (
            <Link
              href={altHref}
              className="shrink-0 text-sm underline underline-offset-4 text-[var(--color-mute,#6b7280)] hover:text-[var(--color-fg,#111827)]"
            >
              {altLabel}
            </Link>
          )}
        </div>
        <p className="mt-3 text-sm text-[var(--color-mute,#6b7280)]">
          {updatedLabel}: {updated}
        </p>
        <div className="mt-10 space-y-10">{children}</div>
      </main>
      <Footer />
    </>
  );
}

export function LegalSection({
  heading,
  children,
}: {
  heading: string;
  children: ReactNode;
}) {
  return (
    <section>
      <h2 className="text-lg font-semibold">{heading}</h2>
      <p className="mt-3 text-[15px] leading-relaxed text-[var(--color-mute,#4b5563)]">
        {children}
      </p>
    </section>
  );
}
