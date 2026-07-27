"use client";

/**
 * Topic curation UI (spec-13 §15-4: 3–5 live topics/day).
 *
 * Publishing is the consequential action here, so the flow makes it deliberate:
 * new topics default to `draft`, and going live is a separate click on a row you
 * can already see. A draft is invisible to the app (`topics_feed` filters it),
 * which is what makes it safe to write one mid-thought.
 */

import { useCallback, useEffect, useState } from "react";
import { Loader2, Plus, Eye, EyeOff, Archive, RefreshCw } from "lucide-react";
import { TOPIC_CATEGORIES, type AdminTopic, type TopicStatus } from "@/types";

const STATUS_STYLE: Record<TopicStatus, { label: string; color: string }> = {
  draft: { label: "Draft", color: "#8b8ba4" },
  live: { label: "Live", color: "#22c55e" },
  closed: { label: "Closed", color: "#f59e0b" },
};

async function fetchTopics(): Promise<AdminTopic[]> {
  const response = await fetch("/api/topics", { cache: "no-store" });
  const body = (await response.json()) as { topics?: AdminTopic[]; error?: string };
  if (!response.ok) throw new Error(body.error ?? "Could not load topics.");
  return body.topics ?? [];
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : "Something went wrong.";
}

export function TopicsClient() {
  const [topics, setTopics] = useState<AdminTopic[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

  /// Used by the Refresh button and after a create. The mount fetch deliberately
  /// does *not* go through here: `isLoading` already starts true, and calling a
  /// setState-bearing function straight from an effect costs a cascading render.
  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setTopics(await fetchTopics());
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setIsLoading(false);
    }
  }, []);

  // State is only touched from promise callbacks, and the cancel flag stops a
  // slow response from writing to an unmounted screen.
  useEffect(() => {
    let cancelled = false;
    fetchTopics()
      .then((list) => {
        if (!cancelled) setTopics(list);
      })
      .catch((e: unknown) => {
        if (!cancelled) setError(messageOf(e));
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  async function setStatus(topic: AdminTopic, status: TopicStatus) {
    setPendingId(topic.id);
    setError(null);
    try {
      const response = await fetch(`/api/topics/${topic.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? "Could not update the topic.");
      setTopics((current) =>
        current.map((t) => (t.id === topic.id ? { ...t, status } : t))
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not update the topic.");
    } finally {
      setPendingId(null);
    }
  }

  const liveCount = topics.filter((t) => t.status === "live").length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "Live today", value: String(liveCount), color: liveCount >= 3 ? "#22c55e" : "#f59e0b" },
          { label: "Drafts", value: String(topics.filter((t) => t.status === "draft").length), color: "#8b8ba4" },
          { label: "Total", value: String(topics.length), color: "#4f8ef7" },
        ].map((s) => (
          <div key={s.label} className="bg-[#0d0d1f] border border-white/6 rounded-xl px-5 py-4">
            <p className="text-xs text-[#52526c] uppercase tracking-wider mb-1">{s.label}</p>
            <p className="text-2xl font-bold tabular-nums" style={{ color: s.color }}>
              {s.value}
            </p>
          </div>
        ))}
      </div>

      {liveCount < 3 && !isLoading && (
        <p className="text-xs text-[#f59e0b]">
          The plan calls for 3–5 live topics a day — {liveCount} live right now.
        </p>
      )}

      <CreateTopicForm onCreated={load} />

      {error && (
        <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      <div className="bg-[#0d0d1f] border border-white/6 rounded-xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-3 border-b border-white/6">
          <h2 className="text-sm font-semibold text-[#f4f4f6]">Topics</h2>
          <button
            onClick={() => void load()}
            className="flex items-center gap-1.5 text-xs text-[#8b8ba4] hover:text-[#f4f4f6] transition-colors"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            Refresh
          </button>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-14 text-[#52526c]">
            <Loader2 className="h-5 w-5 animate-spin" />
          </div>
        ) : topics.length === 0 ? (
          <div className="py-14 text-center">
            <p className="text-sm text-[#8b8ba4]">No topics yet.</p>
            <p className="text-xs text-[#52526c] mt-1">
              Create one above — without a live topic the World tab has nothing to show.
            </p>
          </div>
        ) : (
          <ul className="divide-y divide-white/6">
            {topics.map((topic) => {
              const style = STATUS_STYLE[topic.status];
              const isPending = pendingId === topic.id;
              return (
                <li key={topic.id} className="flex items-center gap-4 px-5 py-3.5">
                  <span className="text-xl w-7 text-center flex-shrink-0">
                    {topic.coverEmoji ?? "🌐"}
                  </span>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium text-[#f4f4f6] truncate">{topic.title}</p>
                    <p className="text-xs text-[#52526c] truncate">
                      {topic.category}
                      {topic.subtitle ? ` · ${topic.subtitle}` : ""}
                    </p>
                  </div>
                  <div className="text-right flex-shrink-0 w-20">
                    <p className="text-sm font-semibold text-[#f4f4f6] tabular-nums">
                      {topic.postsCount > 0 ? topic.globalScore : "—"}
                    </p>
                    <p className="text-[10px] text-[#52526c]">{topic.postsCount} scores</p>
                  </div>
                  <span
                    className="text-[10px] font-semibold uppercase tracking-wider px-2 py-1 rounded-md flex-shrink-0"
                    style={{ color: style.color, backgroundColor: `${style.color}1f` }}
                  >
                    {style.label}
                  </span>
                  <div className="flex items-center gap-1.5 flex-shrink-0 w-24 justify-end">
                    {isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin text-[#52526c]" />
                    ) : (
                      <>
                        {topic.status !== "live" && (
                          <StatusButton
                            title="Publish"
                            onClick={() => void setStatus(topic, "live")}
                            icon={<Eye className="h-3.5 w-3.5" />}
                          />
                        )}
                        {topic.status === "live" && (
                          <StatusButton
                            title="Unpublish (back to draft)"
                            onClick={() => void setStatus(topic, "draft")}
                            icon={<EyeOff className="h-3.5 w-3.5" />}
                          />
                        )}
                        {topic.status !== "closed" && (
                          <StatusButton
                            title="Close (read-only)"
                            onClick={() => void setStatus(topic, "closed")}
                            icon={<Archive className="h-3.5 w-3.5" />}
                          />
                        )}
                      </>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}

function StatusButton({
  title,
  onClick,
  icon,
}: {
  title: string;
  onClick: () => void;
  icon: React.ReactNode;
}) {
  return (
    <button
      title={title}
      onClick={onClick}
      className="p-1.5 rounded-md text-[#8b8ba4] hover:text-[#f4f4f6] hover:bg-white/5 transition-colors"
    >
      {icon}
    </button>
  );
}

function CreateTopicForm({ onCreated }: { onCreated: () => Promise<void> }) {
  const [category, setCategory] = useState<string>(TOPIC_CATEGORIES[0]);
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [coverEmoji, setCoverEmoji] = useState("");
  const [publishNow, setPublishNow] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = title.trim().length > 0 && !isSubmitting;

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!canSubmit) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const response = await fetch("/api/topics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          category,
          title,
          subtitle,
          coverEmoji,
          status: publishNow ? "live" : "draft",
        }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? "Could not create the topic.");
      setTitle("");
      setSubtitle("");
      setCoverEmoji("");
      setPublishNow(false);
      await onCreated();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not create the topic.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form
      onSubmit={submit}
      className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5 space-y-4"
    >
      <h2 className="text-sm font-semibold text-[#f4f4f6]">New topic</h2>

      <div className="grid grid-cols-12 gap-3">
        <label className="col-span-2 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">Emoji</span>
          <input
            value={coverEmoji}
            onChange={(e) => setCoverEmoji(e.target.value)}
            placeholder="🏀"
            maxLength={4}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] text-center focus:outline-none focus:border-[#f42525]/60"
          />
        </label>

        <label className="col-span-3 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">Category</span>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] focus:outline-none focus:border-[#f42525]/60"
          >
            {TOPIC_CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </label>

        <label className="col-span-7 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">
            Title <span className="text-[#52526c]/70">({title.trim().length}/80)</span>
          </span>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="지금 내 연애 온도"
            maxLength={80}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] focus:outline-none focus:border-[#f42525]/60"
          />
        </label>

        <label className="col-span-12 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">
            Subtitle <span className="text-[#52526c]/70">(optional)</span>
          </span>
          <input
            value={subtitle}
            onChange={(e) => setSubtitle(e.target.value)}
            placeholder="사람들의 실시간 감정"
            maxLength={200}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] focus:outline-none focus:border-[#f42525]/60"
          />
        </label>
      </div>

      {error && <p className="text-xs text-red-300">{error}</p>}

      <div className="flex items-center justify-between">
        <label className="flex items-center gap-2 text-xs text-[#8b8ba4] cursor-pointer">
          <input
            type="checkbox"
            checked={publishNow}
            onChange={(e) => setPublishNow(e.target.checked)}
            className="accent-[#f42525]"
          />
          Publish immediately (visible in the app)
        </label>

        <button
          type="submit"
          disabled={!canSubmit}
          className="flex items-center gap-2 bg-[#f42525] text-white text-sm font-semibold px-4 py-2 rounded-lg disabled:opacity-40 hover:bg-[#f42525]/90 transition-colors"
        >
          {isSubmitting ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Plus className="h-4 w-4" />
          )}
          Create
        </button>
      </div>
    </form>
  );
}
