import { SectionHeading } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/motion/Reveal";
import { DAILY_CARDS } from "@/lib/data";
import { scoreColor, scoreLabel } from "@/lib/utils";

/** Duplicate the cards so the marquee loops seamlessly. */
const MARQUEE = [...DAILY_CARDS, ...DAILY_CARDS];

function Card({ emoji, label, score, reason, when }: (typeof DAILY_CARDS)[number]) {
  return (
    <div className="w-64 shrink-0 rounded-3xl bg-white p-5 ring-1 ring-[var(--color-line)] shadow-[0_20px_50px_-30px_rgba(0,0,0,0.3)]">
      <div className="flex items-start justify-between">
        <div className="flex items-center gap-2.5">
          <span className="grid h-10 w-10 place-items-center rounded-2xl bg-[var(--color-canvas)] text-xl">
            {emoji}
          </span>
          <div>
            <p className="text-sm font-bold">{label}</p>
            <p className="text-[11px] text-[var(--color-text-3)]">{when}</p>
          </div>
        </div>
        <span className="text-3xl font-bold" style={{ color: scoreColor(score) }}>
          {score}
        </span>
      </div>
      <p className="mt-3 text-sm leading-snug text-[var(--color-text-2)]">&ldquo;{reason}&rdquo;</p>
      <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-[var(--color-canvas)] px-2.5 py-1 text-[11px] font-semibold" style={{ color: scoreColor(score) }}>
        {scoreLabel(score)}
      </div>
    </div>
  );
}

export function DailyLife() {
  return (
    <section className="overflow-hidden py-24">
      <div className="px-5">
        <SectionHeading
          eyebrow="Daily life"
          title={<>Score the little things,<br className="hidden sm:block" /> every day</>}
          subtitle="Coffee, work, the gym, your mood, a date. The small scores add up to the bigger picture."
        />
      </div>

      <Reveal className="mt-14">
        <div className="relative">
          {/* edge fades */}
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-24 bg-gradient-to-r from-[var(--color-canvas)] to-transparent" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-24 bg-gradient-to-l from-[var(--color-canvas)] to-transparent" />
          <div className="flex w-max gap-5 animate-marquee py-2 [animation-play-state:running] hover:[animation-play-state:paused]">
            {MARQUEE.map((c, i) => (
              <Card key={`${c.id}-${i}`} {...c} />
            ))}
          </div>
        </div>
      </Reveal>
    </section>
  );
}
