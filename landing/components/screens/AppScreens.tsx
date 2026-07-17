import { Home, Globe2, Plus, BarChart3, User } from "lucide-react";
import {
  DAILY_CARDS,
  WORLD_TOPICS,
  HEATMAP,
  WEEKLY_TREND,
  FEED,
  type ScreenId,
} from "@/lib/data";
import { scoreColor, scoreLabel, formatCompact } from "@/lib/utils";

/* ---------- shared chrome ---------- */

function TabBar({ active }: { active: number }) {
  const tabs = [
    { Icon: Home },
    { Icon: Globe2 },
    { Icon: Plus, fab: true },
    { Icon: BarChart3 },
    { Icon: User },
  ];
  return (
    <div className="absolute inset-x-0 bottom-0 z-20 flex items-center justify-around border-t border-[var(--color-line)] bg-white/90 px-3 pb-5 pt-3 backdrop-blur">
      {tabs.map(({ Icon, fab }, i) =>
        fab ? (
          <div
            key={i}
            className="grid h-11 w-11 -translate-y-3 place-items-center rounded-2xl bg-[var(--color-brand)] text-white shadow-[0_8px_20px_-6px_rgba(206,59,34,0.7)]"
          >
            <Icon size={22} strokeWidth={2.4} />
          </div>
        ) : (
          <Icon
            key={i}
            size={22}
            strokeWidth={2.2}
            className={i === active ? "text-[var(--color-brand)]" : "text-[var(--color-text-3)]"}
          />
        )
      )}
    </div>
  );
}

function Bars({ values, color }: { values: number[]; color?: string }) {
  const max = Math.max(...values);
  return (
    <div className="flex h-full items-end gap-1.5">
      {values.map((v, i) => (
        <div
          key={i}
          className="flex-1 rounded-full"
          style={{
            height: `${(v / max) * 100}%`,
            background: color ?? scoreColor(v),
            opacity: 0.55 + (i / values.length) * 0.45,
          }}
        />
      ))}
    </div>
  );
}

/* ---------- screens ---------- */

function HomeScreen() {
  const today = 82;
  return (
    <div className="h-full bg-[var(--color-canvas)] pt-11">
      <div className="px-5 pt-2">
        <p className="text-[11px] font-medium text-[var(--color-text-3)]">Tuesday, June 11</p>
        <h2 className="text-[19px] font-bold tracking-tight">Good evening, Alex</h2>
      </div>

      {/* hero score card */}
      <div className="mx-4 mt-3 rounded-3xl bg-[var(--color-ink)] p-5 text-white">
        <p className="text-[11px] font-medium opacity-70">Today&apos;s score</p>
        <div className="mt-1 flex items-end gap-2">
          <span className="text-[56px] font-bold leading-none" style={{ color: scoreColor(today) }}>
            {today}
          </span>
          <span className="mb-2 text-sm font-semibold opacity-80">{scoreLabel(today)}</span>
        </div>
        <p className="mt-2 text-[12px] leading-snug opacity-75">
          &ldquo;Shipped the thing. Felt good.&rdquo;
        </p>
      </div>

      {/* daily cards grid */}
      <div className="mt-4 grid grid-cols-2 gap-2.5 px-4">
        {DAILY_CARDS.slice(1, 5).map((c) => (
          <div key={c.id} className="rounded-2xl bg-white p-3 shadow-[0_2px_10px_-6px_rgba(0,0,0,0.2)]">
            <div className="flex items-center justify-between">
              <span className="text-lg">{c.emoji}</span>
              <span className="text-lg font-bold" style={{ color: scoreColor(c.score) }}>
                {c.score}
              </span>
            </div>
            <p className="mt-1 text-[12px] font-semibold">{c.label}</p>
            <p className="truncate text-[10px] text-[var(--color-text-3)]">{c.reason}</p>
          </div>
        ))}
      </div>
      <TabBar active={0} />
    </div>
  );
}

function DailyScoreScreen() {
  const value = 82;
  return (
    <div className="flex h-full flex-col bg-[var(--color-canvas)] pt-12">
      <div className="px-5">
        <p className="text-[11px] font-medium text-[var(--color-text-3)]">New score</p>
        <h2 className="text-[19px] font-bold tracking-tight">How was today?</h2>
      </div>

      <div className="mt-2 grid flex-1 place-items-center">
        <div className="relative grid place-items-center">
          <div
            className="text-[88px] font-bold leading-none tracking-tighter"
            style={{ color: scoreColor(value) }}
          >
            {value}
          </div>
          <p className="text-sm font-semibold text-[var(--color-text-2)]">{scoreLabel(value)} day</p>
        </div>
      </div>

      {/* slider track */}
      <div className="px-6">
        <div className="relative h-3 rounded-full" style={{ background: "linear-gradient(90deg,#e23a2e,#f5a623,#1fc77b)" }}>
          <div
            className="absolute top-1/2 h-7 w-7 -translate-y-1/2 rounded-full border-4 border-white bg-[var(--color-ink)] shadow-lg"
            style={{ left: `calc(${value}% - 14px)` }}
          />
        </div>
        <div className="mt-2 flex justify-between text-[10px] font-medium text-[var(--color-text-3)]">
          <span>0</span><span>50</span><span>100</span>
        </div>
      </div>

      {/* reason field */}
      <div className="mx-5 mb-6 mt-4 rounded-2xl bg-white p-3 shadow-[0_2px_10px_-6px_rgba(0,0,0,0.18)]">
        <p className="text-[12px] text-[var(--color-text-2)]">
          Shipped the thing. Felt good.<span className="ml-0.5 inline-block h-3.5 w-[2px] translate-y-0.5 bg-[var(--color-brand)]" />
        </p>
      </div>
      <div className="mx-5 mb-7 grid h-12 place-items-center rounded-2xl bg-[var(--color-brand)] font-semibold text-white">
        Save score
      </div>
    </div>
  );
}

function WorldScreen() {
  return (
    <div className="h-full bg-[var(--color-canvas)] pt-11">
      <div className="px-5 pt-2">
        <h2 className="text-[19px] font-bold tracking-tight">World</h2>
        <p className="text-[11px] font-medium text-[var(--color-text-3)]">How the planet feels, right now</p>
      </div>
      <div className="mt-3 space-y-2 px-4">
        {WORLD_TOPICS.slice(0, 6).map((t) => (
          <div key={t.id} className="flex items-center gap-3 rounded-2xl bg-white p-3 shadow-[0_2px_10px_-7px_rgba(0,0,0,0.2)]">
            <div
              className="grid h-9 w-9 place-items-center rounded-xl text-sm font-bold text-white"
              style={{ background: scoreColor(t.score) }}
            >
              {t.score}
            </div>
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-semibold">{t.name}</p>
              <p className="text-[10px] text-[var(--color-text-3)]">{formatCompact(t.votes)} scores</p>
            </div>
            <span className={`text-[11px] font-semibold ${t.delta >= 0 ? "text-[#1fa968]" : "text-[#e23a2e]"}`}>
              {t.delta >= 0 ? "▲" : "▼"} {Math.abs(t.delta)}
            </span>
          </div>
        ))}
      </div>
      <TabBar active={1} />
    </div>
  );
}

function TimelineScreen() {
  return (
    <div className="h-full bg-[var(--color-canvas)] pt-11">
      <div className="px-5 pt-2">
        <h2 className="text-[19px] font-bold tracking-tight">Timeline</h2>
        <p className="text-[11px] font-medium text-[var(--color-text-3)]">Everything you&apos;ve scored</p>
      </div>
      <div className="relative mt-3 px-5">
        <div className="absolute bottom-2 left-[26px] top-2 w-[2px] bg-[var(--color-line-strong)]" />
        <div className="space-y-3">
          {DAILY_CARDS.slice(0, 5).map((c) => (
            <div key={c.id} className="relative flex gap-3">
              <div
                className="z-10 grid h-[18px] w-[18px] shrink-0 place-items-center rounded-full ring-4 ring-[var(--color-canvas)]"
                style={{ background: scoreColor(c.score) }}
              />
              <div className="flex-1 rounded-2xl bg-white p-3 shadow-[0_2px_10px_-7px_rgba(0,0,0,0.2)]">
                <div className="flex items-center justify-between">
                  <span className="text-[13px] font-semibold">{c.emoji} {c.label}</span>
                  <span className="text-base font-bold" style={{ color: scoreColor(c.score) }}>{c.score}</span>
                </div>
                <p className="truncate text-[11px] text-[var(--color-text-3)]">{c.reason}</p>
              </div>
            </div>
          ))}
        </div>
      </div>
      <TabBar active={0} />
    </div>
  );
}

function StatsScreen() {
  return (
    <div className="h-full bg-[var(--color-canvas)] pt-11">
      <div className="px-5 pt-2">
        <h2 className="text-[19px] font-bold tracking-tight">Statistics</h2>
        <p className="text-[11px] font-medium text-[var(--color-text-3)]">Your scoring patterns</p>
      </div>

      <div className="mx-4 mt-3 rounded-3xl bg-white p-4 shadow-[0_2px_12px_-8px_rgba(0,0,0,0.2)]">
        <div className="flex items-baseline justify-between">
          <span className="text-[12px] font-medium text-[var(--color-text-2)]">Weekly average</span>
          <span className="text-[11px] font-semibold text-[#1fa968]">+8.4%</span>
        </div>
        <div className="mt-1 text-3xl font-bold">76</div>
        <div className="mt-3 h-20">
          <Bars values={WEEKLY_TREND} />
        </div>
      </div>

      <div className="mt-3 grid grid-cols-3 gap-2.5 px-4">
        {[["48", "🔥 streak"], ["1.2K", "scores"], ["92", "best"]].map(([v, l]) => (
          <div key={l} className="rounded-2xl bg-white p-3 text-center shadow-[0_2px_10px_-7px_rgba(0,0,0,0.2)]">
            <div className="text-xl font-bold">{v}</div>
            <div className="text-[10px] text-[var(--color-text-3)]">{l}</div>
          </div>
        ))}
      </div>

      {/* heatmap */}
      <div className="mx-4 mt-3 rounded-3xl bg-white p-4 shadow-[0_2px_12px_-8px_rgba(0,0,0,0.2)]">
        <p className="mb-2 text-[12px] font-medium text-[var(--color-text-2)]">Last 30 days</p>
        <div className="grid grid-cols-10 gap-1">
          {HEATMAP.map((v, i) => (
            <div key={i} className="aspect-square rounded-[5px]" style={{ background: scoreColor(v), opacity: 0.35 + (v / 100) * 0.65 }} />
          ))}
        </div>
      </div>
      <TabBar active={3} />
    </div>
  );
}

function ProfileScreen() {
  const post = FEED[0];
  return (
    <div className="h-full bg-[var(--color-canvas)] pt-11">
      <div className="flex flex-col items-center px-5 pt-3">
        <div className="grid h-16 w-16 place-items-center rounded-full bg-[var(--color-brand-tint)] text-3xl ring-4 ring-white">
          🦊
        </div>
        <h2 className="mt-2 text-[17px] font-bold tracking-tight">Maya</h2>
        <p className="text-[11px] text-[var(--color-text-3)]">@mayadraws</p>
        <div className="mt-3 flex gap-6 text-center">
          {[["1.2K", "scores"], ["980", "followers"], ["312", "following"]].map(([v, l]) => (
            <div key={l}>
              <div className="text-base font-bold">{v}</div>
              <div className="text-[10px] text-[var(--color-text-3)]">{l}</div>
            </div>
          ))}
        </div>
      </div>
      <div className="mx-4 mt-4 rounded-2xl bg-white p-3 shadow-[0_2px_10px_-7px_rgba(0,0,0,0.2)]">
        <div className="flex items-center justify-between">
          <span className="text-[13px] font-semibold">{post.target}</span>
          <span className="text-lg font-bold" style={{ color: scoreColor(post.score) }}>{post.score}</span>
        </div>
        <p className="text-[11px] text-[var(--color-text-2)]">{post.reason}</p>
        <div className="mt-2 flex gap-4 text-[11px] text-[var(--color-text-3)]">
          <span>❤️ {formatCompact(post.likes)}</span>
          <span>💬 {post.comments}</span>
        </div>
      </div>
      <TabBar active={4} />
    </div>
  );
}

export const SCREEN_COMPONENTS: Record<ScreenId, () => React.JSX.Element> = {
  home: HomeScreen,
  daily: DailyScoreScreen,
  world: WorldScreen,
  timeline: TimelineScreen,
  stats: StatsScreen,
  profile: ProfileScreen,
};

export function AppScreen({ id }: { id: ScreenId }) {
  const Comp = SCREEN_COMPONENTS[id];
  return <Comp />;
}
