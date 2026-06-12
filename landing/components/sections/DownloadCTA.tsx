"use client";

import { motion } from "framer-motion";
import { ArrowUpRight } from "lucide-react";
import { AppStoreBadge, PlayStoreBadge, DownloadQR } from "@/components/ui/StoreBadges";
import { openInApp } from "@/lib/deeplink";
import { scoreColor } from "@/lib/utils";

const CONFETTI = [88, 42, 95, 30, 71, 60, 82, 24, 99, 55, 77, 38];

export function DownloadCTA() {
  return (
    <section id="download" className="px-5 pb-24 pt-6">
      <div className="relative mx-auto max-w-5xl overflow-hidden rounded-[40px] bg-[var(--color-ink)] px-6 py-16 text-center text-white sm:px-12">
        {/* floating score confetti */}
        {CONFETTI.map((v, i) => (
          <motion.span
            key={i}
            aria-hidden
            initial={{ opacity: 0 }}
            whileInView={{ opacity: 0.9 }}
            viewport={{ once: true }}
            transition={{ delay: i * 0.05 }}
            className="pointer-events-none absolute hidden text-sm font-bold sm:block"
            style={{
              color: scoreColor(v),
              left: `${(i * 8.3 + 4) % 96}%`,
              top: `${(i * 31) % 88 + 4}%`,
              transform: `rotate(${(i % 5) * 9 - 18}deg)`,
            }}
          >
            {v}
          </motion.span>
        ))}

        <div className="relative">
          <h2 className="mx-auto max-w-2xl text-balance text-4xl font-bold tracking-tight sm:text-5xl">
            What score would you give it?
          </h2>
          <p className="mx-auto mt-4 max-w-lg text-balance text-lg text-white/65">
            Join millions scoring their day and the world. Free to download.
          </p>

          <div className="mt-10 flex flex-col items-center justify-center gap-8 sm:flex-row sm:items-center">
            <div className="flex flex-col items-center gap-3">
              <div className="flex flex-wrap justify-center gap-3">
                <AppStoreBadge />
                <PlayStoreBadge />
              </div>
              <button
                onClick={() => openInApp("")}
                className="inline-flex items-center gap-1.5 text-sm font-semibold text-white/80 underline-offset-4 transition-colors hover:text-white hover:underline"
              >
                Already have it? Open in Scoor
                <ArrowUpRight size={15} />
              </button>
            </div>

            <div className="hidden h-28 w-px bg-white/15 sm:block" />

            <div className="flex flex-col items-center gap-2">
              <DownloadQR />
              <p className="text-xs text-white/55">Scan to download</p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
