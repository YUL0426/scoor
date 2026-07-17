import { SectionHeading } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/motion/Reveal";
import { scoreColor } from "@/lib/utils";

const STEPS = [
  {
    n: "01",
    title: "Score",
    body: "Give anything a score from 0 to 100. Your day, a coffee, a movie, a mood.",
    visual: "dial",
  },
  {
    n: "02",
    title: "Explain",
    body: "Add a short reason. One line is enough — it's what makes a score real.",
    visual: "reason",
  },
  {
    n: "03",
    title: "Track",
    body: "Watch your score history evolve into trends, streaks, and patterns.",
    visual: "trend",
  },
] as const;

function StepVisual({ kind }: { kind: string }) {
  if (kind === "dial") {
    return (
      <div className="grid h-28 place-items-center">
        <div className="text-[64px] font-bold leading-none" style={{ color: scoreColor(82) }}>
          82
        </div>
      </div>
    );
  }
  if (kind === "reason") {
    return (
      <div className="grid h-28 place-items-center px-4">
        <div className="w-full rounded-2xl bg-[var(--color-canvas)] p-3 text-sm text-[var(--color-text-2)] ring-1 ring-[var(--color-line)]">
          &ldquo;Shipped the thing. Felt good.&rdquo;
          <span className="ml-0.5 inline-block h-4 w-[2px] translate-y-0.5 animate-pulse bg-[var(--color-brand)]" />
        </div>
      </div>
    );
  }
  return (
    <div className="flex h-28 items-end gap-1.5 px-6">
      {[40, 55, 48, 70, 62, 80, 76].map((v, i) => (
        <div
          key={i}
          className="flex-1 rounded-full"
          style={{ height: `${v}%`, background: scoreColor(v) }}
        />
      ))}
    </div>
  );
}

export function HowItWorks() {
  return (
    <section id="how" className="px-5 py-24">
      <div className="mx-auto max-w-6xl">
        <SectionHeading
          eyebrow="How Scoor works"
          title="Three taps to a feeling"
          subtitle="No surveys. No forms. Just a number, a reason, and a story that builds over time."
        />
        <div className="mt-14 grid gap-5 md:grid-cols-3">
          {STEPS.map((s, i) => (
            <Reveal key={s.n} index={i}>
              <div className="group h-full rounded-[var(--radius-card)] bg-white p-6 ring-1 ring-[var(--color-line)] transition-all duration-300 hover:-translate-y-1 hover:shadow-[0_30px_60px_-30px_rgba(0,0,0,0.25)]">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-bold text-[var(--color-text-3)]">{s.n}</span>
                  <span className="rounded-full bg-[var(--color-brand-tint)] px-3 py-1 text-xs font-semibold text-[var(--color-brand)]">
                    Step {i + 1}
                  </span>
                </div>
                <div className="my-4 overflow-hidden rounded-2xl bg-[var(--color-canvas)] ring-1 ring-[var(--color-line)]">
                  <StepVisual kind={s.visual} />
                </div>
                <h3 className="text-xl font-bold tracking-tight">{s.title}</h3>
                <p className="mt-2 text-[15px] leading-relaxed text-[var(--color-text-2)]">{s.body}</p>
              </div>
            </Reveal>
          ))}
        </div>
      </div>
    </section>
  );
}
