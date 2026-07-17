import type { ReactNode } from "react";
import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";

/** Shared shell for legal documents (/privacy, /terms). */
export function LegalPage({
  title,
  updated,
  children,
}: {
  title: string;
  updated: string;
  children: ReactNode;
}) {
  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-3xl px-6 pb-24 pt-32">
        <h1 className="text-4xl font-bold tracking-tight">{title}</h1>
        <p className="mt-3 text-sm text-[var(--color-mute,#6b7280)]">
          Last updated: {updated}
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
