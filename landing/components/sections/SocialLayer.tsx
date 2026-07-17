import { Heart, MessageCircle, Users, Trophy } from "lucide-react";
import { SectionHeading } from "@/components/ui/SectionHeading";
import { Reveal } from "@/components/motion/Reveal";
import { FEED } from "@/lib/data";
import { scoreColor, formatCompact } from "@/lib/utils";

const FEATURES = [
  { Icon: Users, title: "Friends & followers", body: "Follow the people whose taste you trust." },
  { Icon: MessageCircle, title: "Comments & reactions", body: "Every score is a conversation starter." },
  { Icon: Trophy, title: "Global rankings", body: "See the top scores and the loudest opinions." },
];

function FeedPost({ post }: { post: (typeof FEED)[number] }) {
  return (
    <div className="rounded-3xl bg-white p-4 ring-1 ring-[var(--color-line)] shadow-[0_20px_50px_-34px_rgba(0,0,0,0.35)]">
      <div className="flex items-center gap-3">
        <span className="grid h-10 w-10 place-items-center rounded-full bg-[var(--color-canvas)] text-xl">
          {post.avatar}
        </span>
        <div className="flex-1">
          <p className="text-sm font-semibold">
            {post.user} <span className="font-normal text-[var(--color-text-3)]">{post.handle}</span>
          </p>
          <p className="text-[11px] text-[var(--color-text-3)]">scored {post.target} · {post.when}</p>
        </div>
        <span className="text-2xl font-bold" style={{ color: scoreColor(post.score) }}>{post.score}</span>
      </div>
      <p className="mt-3 text-[15px] leading-snug text-[var(--color-text)]">&ldquo;{post.reason}&rdquo;</p>
      <div className="mt-3 flex items-center gap-5 text-[13px] text-[var(--color-text-3)]">
        <span className="inline-flex items-center gap-1.5"><Heart size={15} className="text-[var(--color-brand)]" fill="currentColor" /> {formatCompact(post.likes)}</span>
        <span className="inline-flex items-center gap-1.5"><MessageCircle size={15} /> {post.comments}</span>
      </div>
    </div>
  );
}

export function SocialLayer() {
  return (
    <section id="social" className="px-5 py-24">
      <div className="mx-auto max-w-6xl">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <SectionHeading
              align="left"
              eyebrow="Social layer"
              title="Scoring is better together"
              subtitle="Scoor is a social network built around one question. Share scores, react, comment, and climb the rankings."
            />
            <div className="mt-8 space-y-4">
              {FEATURES.map((f, i) => (
                <Reveal key={f.title} index={i}>
                  <div className="flex items-start gap-4">
                    <span className="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-[var(--color-brand-tint)] text-[var(--color-brand)]">
                      <f.Icon size={20} />
                    </span>
                    <div>
                      <p className="font-semibold">{f.title}</p>
                      <p className="text-sm text-[var(--color-text-2)]">{f.body}</p>
                    </div>
                  </div>
                </Reveal>
              ))}
            </div>
          </div>

          <div className="space-y-4">
            {FEED.map((p, i) => (
              <Reveal key={p.id} index={i}>
                <FeedPost post={p} />
              </Reveal>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
