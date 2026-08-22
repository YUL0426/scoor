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
import {
  TOPIC_CATEGORIES,
  TOPIC_CATEGORY_LABELS,
  type AdminTopic,
  type TopicStatus,
} from "@/types";

/// 카테고리는 DB에 원시 값으로 저장된다. 목록에 새 값이 생겨도 화면이 비지
/// 않도록, 라벨이 없으면 원시 값을 그대로 보여준다.
function categoryLabel(raw: string): string {
  return (TOPIC_CATEGORY_LABELS as Record<string, string>)[raw] ?? raw;
}

const STATUS_STYLE: Record<TopicStatus, { label: string; color: string }> = {
  draft: { label: "초안", color: "#8b8ba4" },
  live: { label: "공개", color: "#22c55e" },
  closed: { label: "마감", color: "#f59e0b" },
};

async function fetchTopics(): Promise<AdminTopic[]> {
  const response = await fetch("/api/topics", { cache: "no-store" });
  const body = (await response.json()) as { topics?: AdminTopic[]; error?: string };
  if (!response.ok) throw new Error(body.error ?? "토픽을 불러오지 못했습니다.");
  return body.topics ?? [];
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : "문제가 발생했습니다.";
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
      if (!response.ok) throw new Error(body.error ?? "토픽을 수정하지 못했습니다.");
      setTopics((current) =>
        current.map((t) => (t.id === topic.id ? { ...t, status } : t))
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "토픽을 수정하지 못했습니다.");
    } finally {
      setPendingId(null);
    }
  }

  const liveCount = topics.filter((t) => t.status === "live").length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "오늘 공개", value: String(liveCount), color: liveCount >= 3 ? "#22c55e" : "#f59e0b" },
          { label: "초안", value: String(topics.filter((t) => t.status === "draft").length), color: "#8b8ba4" },
          { label: "전체", value: String(topics.length), color: "#4f8ef7" },
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
          하루 3~5개 공개가 계획입니다 — 지금 공개 중인 토픽은 {liveCount}개입니다.
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
          <h2 className="text-sm font-semibold text-[#f4f4f6]">토픽 목록</h2>
          <button
            onClick={() => void load()}
            className="flex items-center gap-1.5 text-xs text-[#8b8ba4] hover:text-[#f4f4f6] transition-colors"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            새로고침
          </button>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-14 text-[#52526c]">
            <Loader2 className="h-5 w-5 animate-spin" />
          </div>
        ) : topics.length === 0 ? (
          <div className="py-14 text-center">
            <p className="text-sm text-[#8b8ba4]">아직 토픽이 없습니다.</p>
            <p className="text-xs text-[#52526c] mt-1">
              위에서 하나 만들어주세요 — 공개된 토픽이 없으면 앱 월드 탭이 빈 화면이 됩니다.
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
                      {categoryLabel(topic.category)}
                      {topic.subtitle ? ` · ${topic.subtitle}` : ""}
                    </p>
                  </div>
                  <div className="text-right flex-shrink-0 w-20">
                    <p className="text-sm font-semibold text-[#f4f4f6] tabular-nums">
                      {topic.postsCount > 0 ? topic.globalScore : "—"}
                    </p>
                    <p className="text-[10px] text-[#52526c]">점수 {topic.postsCount}개</p>
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
                            title="공개"
                            onClick={() => void setStatus(topic, "live")}
                            icon={<Eye className="h-3.5 w-3.5" />}
                          />
                        )}
                        {topic.status === "live" && (
                          <StatusButton
                            title="공개 해제 (초안으로)"
                            onClick={() => void setStatus(topic, "draft")}
                            icon={<EyeOff className="h-3.5 w-3.5" />}
                          />
                        )}
                        {topic.status !== "closed" && (
                          <StatusButton
                            title="마감 (읽기 전용)"
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
      if (!response.ok) throw new Error(body.error ?? "토픽을 만들지 못했습니다.");
      setTitle("");
      setSubtitle("");
      setCoverEmoji("");
      setPublishNow(false);
      await onCreated();
    } catch (e) {
      setError(e instanceof Error ? e.message : "토픽을 만들지 못했습니다.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form
      onSubmit={submit}
      className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5 space-y-4"
    >
      <h2 className="text-sm font-semibold text-[#f4f4f6]">새 토픽</h2>

      <div className="grid grid-cols-12 gap-3">
        <label className="col-span-2 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">이모지</span>
          <input
            value={coverEmoji}
            onChange={(e) => setCoverEmoji(e.target.value)}
            placeholder="🏀"
            maxLength={4}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] text-center focus:outline-none focus:border-[#f42525]/60"
          />
        </label>

        <label className="col-span-3 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">카테고리</span>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="bg-[#060610] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] focus:outline-none focus:border-[#f42525]/60"
          >
            {TOPIC_CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {TOPIC_CATEGORY_LABELS[c]}
              </option>
            ))}
          </select>
        </label>

        <label className="col-span-7 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#52526c]">
            제목 <span className="text-[#52526c]/70">({title.trim().length}/80)</span>
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
            부제 <span className="text-[#52526c]/70">(선택)</span>
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
          즉시 공개 (앱에 노출)
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
          만들기
        </button>
      </div>
    </form>
  );
}
