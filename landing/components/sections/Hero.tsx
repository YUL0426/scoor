"use client";

import { motion } from "framer-motion";
import { Sparkles } from "lucide-react";
import { PhoneFrame } from "@/components/screens/PhoneFrame";
import { AppScreen } from "@/components/screens/AppScreens";
import { Button } from "@/components/ui/Button";
import { ScoreCounter } from "@/components/motion/ScoreCounter";
import { DEEP_LINKS } from "@/lib/site";
import { scoreColor } from "@/lib/utils";

function FloatingCard({
  emoji,
  label,
  score,
  className,
  delay,
}: {
  emoji: string;
  label: string;
  score: number;
  className: string;
  delay: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.7, y: 20 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ delay, duration: 0.8, ease: [0.16, 1, 0.3, 1] }}
      className={`absolute z-20 ${className}`}
    >
      <div className="animate-float rounded-2xl bg-white/85 p-3 shadow-[0_18px_50px_-18px_rgba(0,0,0,0.4)] ring-1 ring-[var(--color-line)] backdrop-blur-xl" style={{ animationDelay: `${delay}s` }}>
        <div className="flex items-center gap-2.5">
          <span className="text-xl">{emoji}</span>
          <div className="leading-tight">
            <p className="text-[11px] font-medium text-[var(--color-text-3)]">{label}</p>
            <p className="text-lg font-bold" style={{ color: scoreColor(score) }}>{score}</p>
          </div>
        </div>
      </div>
    </motion.div>
  );
}

export function Hero() {
  return (
    <section id="top" className="relative px-5 pb-20 pt-32 md:pt-40">
      <div className="mx-auto grid max-w-6xl items-center gap-10 lg:grid-cols-[1.05fr_0.95fr]">
        {/* Copy */}
        <div className="text-center lg:text-left">
          <motion.div
            initial={{ opacity: 0, y: 14 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6 }}
            className="inline-flex items-center gap-2 rounded-full bg-white/70 px-3.5 py-1.5 text-xs font-semibold text-[var(--color-text-2)] ring-1 ring-[var(--color-line)] backdrop-blur"
          >
            <Sparkles size={13} className="text-[var(--color-brand)]" />
            The social scoring app
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.05 }}
            className="mt-5 text-balance text-5xl font-bold leading-[0.98] tracking-tight sm:text-6xl lg:text-[68px]"
          >
            What score would you give{" "}
            <span className="score-gradient-text">today?</span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.12 }}
            className="mx-auto mt-5 max-w-md text-balance text-lg text-[var(--color-text-2)] lg:mx-0"
          >
            Score your day. Score the world. See how everyone feels — from 0 to
            100, with a reason.
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 18 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.18 }}
            className="mt-8 flex flex-col items-center gap-3 sm:flex-row lg:items-start lg:justify-start"
          >
            <Button href={DEEP_LINKS.open.web} size="lg">
              Download on App Store
            </Button>
            <Button href="#how" variant="ghost" size="lg">
              See how it works
            </Button>
          </motion.div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.7, delay: 0.3 }}
            className="mt-8 flex items-center justify-center gap-6 lg:justify-start"
          >
            <div>
              <div className="text-2xl font-bold">
                <ScoreCounter to={2} decimals={0} />M+
              </div>
              <div className="text-xs text-[var(--color-text-3)]">scores given</div>
            </div>
            <div className="h-8 w-px bg-[var(--color-line-strong)]" />
            <div>
              <div className="text-2xl font-bold">
                <ScoreCounter to={4.9} decimals={1} />
                <span className="text-[var(--color-score-100)]">★</span>
              </div>
              <div className="text-xs text-[var(--color-text-3)]">App Store rating</div>
            </div>
          </motion.div>
        </div>

        {/* Phone + floating cards */}
        <motion.div
          initial={{ opacity: 0, y: 40, rotate: -3 }}
          animate={{ opacity: 1, y: 0, rotate: 0 }}
          transition={{ duration: 1, delay: 0.2, ease: [0.16, 1, 0.3, 1] }}
          className="relative mx-auto flex justify-center"
        >
          <div className="animate-float">
            <PhoneFrame width={300}>
              <AppScreen id="home" />
            </PhoneFrame>
          </div>

          <FloatingCard emoji="☕️" label="Coffee" score={91} delay={0.7} className="-left-2 top-16 sm:left-2" />
          <FloatingCard emoji="🏋️" label="Gym" score={77} delay={0.9} className="-right-1 top-44 sm:right-0" />
          <FloatingCard emoji="💘" label="Date" score={95} delay={1.1} className="-left-3 bottom-28 sm:left-0" />
        </motion.div>
      </div>
    </section>
  );
}
